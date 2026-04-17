---
title: "Step 5: Implementation Reference - SMB Ready Foundation (Terraform)"
status: "Implemented"
date: "2026-04-17"
artifact_version: "1.0"
authors: "Terraform Code Agent"
tags: ["implementation-reference", "terraform", "iac", "azure"]
supersedes: ""
superseded_by: ""
companion: "05-implementation-reference.md"
---

# Step 5: Implementation Reference — SMB Ready Foundation (Terraform)

> Terraform-track companion to [`05-implementation-reference.md`](./05-implementation-reference.md).

## IaC Templates Location

`infra/terraform/smb-ready-foundation/`

## File structure

```text
infra/terraform/smb-ready-foundation/
├── azure.yaml                          # azd manifest (provider: terraform)
├── backend.tf                          # backend "azurerm" {} partial config
├── versions.tf                         # terraform >= 1.9 + provider pins
├── providers.tf                        # azurerm features block + data sources
├── variables.tf                        # Input surface with validation
├── locals.tf                           # Derived values (region short, unique suffix, tags, RG names)
├── main.tf                             # Module orchestration (17 module calls) + root-level `import` block
├── outputs.tf                          # Wired to module outputs (matches Bicep main.bicep)
├── modules/
│   ├── management-group/               # MG + subscription association
│   ├── policy-assignments-mg/          # 33 MG-scoped policy assignments
│   ├── resource-groups/                # 5 shared + 1 spoke RG
│   ├── budget/                         # Consumption budget (sub scope)
│   ├── defender/                       # Defender for Cloud Free pricings + auto-provisioning Off
│   ├── network-hub/                    # Hub VNet, NSG, 4 subnets, privatelink.azure.com PDZ
│   ├── network-spoke/                  # Spoke VNet, NSG, 4 subnets, conditional NAT gateway
│   ├── firewall/                       # Azure Firewall Basic + policy + 2 rule groups (conditional)
│   ├── route-tables/                   # Spoke RT + conditional gateway RT + associations
│   ├── vpn-gateway/                    # VPN Gateway VpnGw1AZ (conditional, serialised after firewall)
│   ├── peering/                        # Hub↔spoke peering with VPN-gated terraform_data relay
│   ├── monitoring/                     # Log Analytics Workspace
│   ├── backup/                         # RSV + DefaultVMPolicy
│   ├── policy-backup-auto/             # Sub-scope DINE policy + role assignments
│   ├── migrate/                        # Azure Migrate project (azapi_resource)
│   ├── keyvault/                       # Key Vault + dedicated PDZ + private endpoint + diagnostic settings
│   └── automation/                     # Automation Account + LAW linked service + diag
├── hooks/
│   ├── _lib.sh                         # Shared bash helpers (CIDR, logging, scenario resolution)
│   ├── _lib.ps1                        # Shared PowerShell helpers
│   ├── pre-provision.sh  / .ps1        # Validate, bootstrap backend, write tfvars, init
│   └── post-provision.sh / .ps1        # Output summary + next steps
├── scripts/
│   ├── bootstrap-tf-backend.sh / .ps1  # Idempotent backend RG + SA + container + backend.hcl
│   ├── remove-smb-ready-foundation.sh
│   └── Remove-SmbReadyFoundation.ps1
├── tests/
│   └── scenarios.tftest.hcl            # 6 plan-mode scenario tests
├── .tflint.hcl                         # tflint config (terraform + azurerm rulesets)
├── .gitignore
├── terraform.tfvars.example
└── README.md
```

CI workflow: `.github/workflows/terraform-smb-ready-foundation.yml`

## Validation status

| Check                                   | Status | Notes                                                          |
| --------------------------------------- | ------ | -------------------------------------------------------------- |
| `terraform fmt -check -recursive`       | ✅ Pass |                                                                |
| `terraform init -backend=false`         | ✅ Pass |                                                                |
| `terraform validate`                    | ✅ Pass | 3 cosmetic v5.0 deprecation warnings (see below).              |
| `terraform test` (plan mode, 6 runs)    | ✅ Pass | All 6 scenario assertions pass.                                |
| `npm run validate:terraform`            | ✅ Pass |                                                                |
| `npm run validate:iac-security-baseline` | ✅ Pass | 44 files, 0 errors, 0 warnings.                                |

### Known warnings (acceptable)

- `azurerm_security_center_auto_provisioning` — deprecated in v5.0 of the azurerm
  provider; behaviour unchanged in 4.x.
- `azurerm_recovery_services_vault.soft_delete_enabled` — deprecated in v5.0;
  soft delete is always on by default.
- `azurerm_monitor_diagnostic_setting.metric` — migrated to `enabled_metric` where applicable;
  some transitive notices remain on v4.x provider messaging.

All will be addressed when this project upgrades to `azurerm ~> 5.0`.

## Resources Created

### Management group scope (`modules/management-group/`, `modules/policy-assignments-mg/`)

| Resource                                              | Purpose                                                  |
| ----------------------------------------------------- | -------------------------------------------------------- |
| `azurerm_management_group.smb_rf`                     | Intermediate MG `smb-rf` under tenant root. Adopted via root-level `import` block targeting `module.management_group.azurerm_management_group.smb_rf`. |
| `azurerm_management_group_subscription_association.primary` | Moves target subscription under `smb-rf`.          |
| `azurerm_management_group_policy_assignment.uniform` (22) | Deny policies: storage, identity, compute, network, monitoring. |
| `azurerm_management_group_policy_assignment.kv_audit` (6) | Audit policies for Key Vault (soft delete, purge protection, etc.). |
| `azurerm_management_group_policy_assignment.compute_01_allowed_skus` | Allowed VM SKUs list. |
| `azurerm_management_group_policy_assignment.tagging_01_environment`  | Require Environment tag. |
| `azurerm_management_group_policy_assignment.tagging_02_owner`        | Require Owner tag.       |
| `azurerm_management_group_policy_assignment.governance_01_allowed_locations` | Allowed regions.  |
| `azurerm_management_group_policy_assignment.monitoring_01_diagnostics` | Deploy-if-not-exists diagnostic settings. |

### Subscription scope

| Resource                                        | Module                         | Notes                                        |
| ----------------------------------------------- | ------------------------------ | -------------------------------------------- |
| `azurerm_consumption_budget_subscription`       | `modules/budget/`              | 3 thresholds (forecast 80 + actual 90/100).  |
| `azurerm_security_center_subscription_pricing` (4) | `modules/defender/`         | Free tier for VMs / Storage / KV / ARM.      |
| `azurerm_security_center_auto_provisioning`     | `modules/defender/`            | Off (v5.0 deprecation).                      |
| `azurerm_subscription_policy_assignment.backup_auto` | `modules/policy-backup-auto/` | DINE for VM backup (tag-based inclusion). |
| `azurerm_role_assignment.backup_auto_*` (2)     | `modules/policy-backup-auto/`  | Backup Contributor + VM Contributor.         |

### Resource-group scope (spoke + 5 shared RGs)

See [`07-resource-inventory-terraform.md`](./07-resource-inventory-terraform.md) for the
full list. Highlights:

- Hub VNet + NSG + 4 subnets (`AzureFirewallSubnet`, `AzureFirewallManagementSubnet`,
  `GatewaySubnet`, `snet-management`) + shared `privatelink.azure.com` Private DNS zone.
- Spoke VNet + NSG + 4 subnets (`snet-workload`, `snet-data`, `snet-app`, `snet-pep`)
  + conditional NAT gateway + conditional route table association.
- Log Analytics Workspace (`log-smbrf-smb-<region>`), Recovery Services Vault
  (`rsv-smbrf-smb-<region>`) + DefaultVMPolicy, Azure Migrate project (`azapi`),
  Key Vault with private endpoint, Automation Account linked to LAW.
- Conditional: Azure Firewall Basic (2 PIPs + policy + 2 rule collection groups),
  VPN Gateway VpnGw1AZ (serialised via `firewall_serialisation_sentinel` input to
  `module.vpn_gateway` for hub-VNet ordering), hub↔spoke peering via
  `module.peering` (2 peerings) gated by `local.deploy_peering`.

## Inputs (variables.tf)

See `variables.tf` for full validation rules. Key variables:

| Variable                          | Type       | Default                 |
| --------------------------------- | ---------- | ----------------------- |
| `subscription_id`                 | GUID       | (required)              |
| `location`                        | string     | `swedencentral`         |
| `environment`                     | string     | `prod`                  |
| `owner`                           | string     | (required)              |
| `hub_vnet_address_space`          | CIDR       | `10.0.0.0/23`           |
| `spoke_vnet_address_space`        | CIDR       | `10.0.2.0/23`           |
| `on_premises_address_space`       | CIDR       | `""`                    |
| `log_analytics_daily_cap_gb`      | number     | `0.5`                   |
| `budget_amount`                   | number     | `100`                   |
| `budget_alert_email`              | string     | `""` (fallback: owner)  |
| `budget_start_date`               | string     | (injected by hook)      |
| `deploy_firewall`                 | bool       | `false`                 |
| `deploy_vpn`                      | bool       | `false`                 |
| `management_group_name`           | string     | `smb-rf`                |
| `allowed_locations`               | list(string) | `["swedencentral", "germanywestcentral", "global"]` |
| `allowed_vm_skus`                 | list(string) | 33 B / D / E series SKUs                          |

## Outputs

See `outputs.tf`. Matches Bicep output surface:

- `deployment_scenario`, `feature_flags`, `resource_group_names`, `unique_suffix`
- `management_group_id`, `management_group_name`, `policy_assignment_count`
- `hub_vnet_id`, `spoke_vnet_id`, `log_analytics_workspace_id`,
  `recovery_services_vault_id`, `migrate_project_id`
- `nat_gateway_name`, `firewall_private_ip`, `vpn_gateway_public_ip` (empty when
  feature disabled)
- `key_vault_name`, `key_vault_uri`, `automation_account_name`

## References

- Bicep reference: [`05-implementation-reference.md`](./05-implementation-reference.md)
- Terraform plan: [`04-implementation-plan-terraform.md`](./04-implementation-plan-terraform.md)
- Resource inventory: [`07-resource-inventory-terraform.md`](./07-resource-inventory-terraform.md)
- ADR-0005 (dual track): [`07-ab-adr-0005-terraform-dual-track.md`](./07-ab-adr-0005-terraform-dual-track.md)
- ADR-0006 (single-root + child modules): [`07-ab-adr-0006-terraform-single-root-composition.md`](./07-ab-adr-0006-terraform-single-root-composition.md)
- Project README: [`infra/terraform/smb-ready-foundation/README.md`](../../infra/terraform/smb-ready-foundation/README.md)
