# Plan: Terraform port of smb-ready-foundation

Port the existing Bicep IaC at `infra/bicep/smb-ready-foundation/` to Terraform at
`infra/terraform/smb-ready-foundation/` (plus `infra/terraform/smb-ready-foundation-mg/`
for MG bootstrap), preserving 100% functional and structural parity (resources, tags,
names, outputs, scenarios, policies).

Strategy: AVM-TF for every module that has a mature AVM equivalent; raw `azurerm_*`
resources only where AVM is missing/immature (Azure Migrate, auto-backup policy
DeployIfNotExists, Defender pricing, consumption budget). `azd up` with
`infra.provider: terraform` (alpha feature — must be enabled) plus full 1:1 hook
parity in Bash **and** PowerShell. Terraform-native guards (`variable.validation`,
`precondition`) are added as defense-in-depth, not as replacements for hook logic.

## Key decisions (from refinement)

- Path: `infra/terraform/smb-ready-foundation/` (main) + `infra/terraform/smb-ready-foundation-mg/` (MG bootstrap)
- AVM-TF maximized; fallback `azurerm_*` only when AVM unavailable
- Dual state backend: azurerm (default) or local, switchable via `TF_BACKEND` azd env var
- Deploy tool: `azd up` with `infra.provider: terraform`
- Hooks: Both PowerShell AND Bash variants, 1:1 ported; azd selects per-OS via
  `hooks.{preprovision,postprovision}.{posix,windows}` (posix→`.sh`, windows→`.ps1`).
  Logic kept in a shared helper library to minimize drift.
- VPN Gateway (Q1): verify `Azure/avm-res-network-virtualnetworkgateway` maturity in
  Phase 1; decide AVM vs. raw `azurerm_virtual_network_gateway` per-module at that gate.
- Azure Migrate (Q2): implement via `azapi_resource` (adds `azapi` provider dependency);
  no AVM-TF module exists.
- Scenarios: per-feature booleans (`deploy_firewall`, `deploy_vpn`) — idiomatic TF
- MG + 30 policies: separate root module run once before main
- Parity target: 100% — same resources, names, tags, outputs
- Agent artifacts: NEW Terraform variants alongside existing Bicep artifacts — do NOT modify existing
- Testing: fmt/validate/tflint + `.tftest.hcl` + e2e apply in CI

## Scope boundaries

- IN: full Terraform re-implementation (2 roots, all modules, azd manifest, hooks, bootstrap, CI, new TF-track artifacts)
- OUT: no changes to existing Bicep project, to existing `agent-output/smb-ready-foundation/` artifacts, or to Bicep CI
- OUT: no cross-provider state sharing between Bicep and TF (independent deploys)

---

## Phase 1 — Scaffolding & conventions

1. Create `infra/terraform/smb-ready-foundation/` with skeleton: `versions.tf`,
   `providers.tf`, `variables.tf`, `locals.tf`, `main.tf`, `outputs.tf`, `azure.yaml`,
   `.gitignore`, `backend.tf` (partial, configured via `-backend-config`).
2. Create `infra/terraform/smb-ready-foundation-mg/` with skeleton for MG bootstrap
   (MG create + subscription association + 30 MG-scoped policy assignments).
3. Pin `terraform >= 1.9`, `azurerm ~> 4.0`, `azapi ~> 2.0` (for Azure Migrate),
   `random`, `null`. Confirm `enable_telemetry` default for AVM modules (leave default
   unless repo convention dictates `false`).
4. **AVM-TF availability gate**: before module-level work begins, verify AVM-TF
   existence and version for: virtualnetworkgateway, recoveryservices-vault (backup
   policies), automationaccount, firewallpolicy, azurefirewall, natgateway, routetable,
   privatednszone, operationalinsights-workspace, keyvault-vault, publicipaddress,
   virtualnetwork, networksecuritygroup, resourcegroup, consumption-budget. Record
   decisions (AVM vs. raw) in a table inside the TF-variant implementation-plan
   artifact (Phase 10). Any `azurerm_*` fallbacks are flagged here, not discovered late.
5. Define `locals.tf` with region map (`swedencentral→swc`, `germanywestcentral→gwc`),
   `rg_names` map, `shared_services_tags`, `spoke_tags`, derived booleans
   (`deploy_peering`, `deploy_spoke_nat_gateway`), and `unique_suffix`. Use
   `random_string` (4 char lowercase) **and** `substr(sha1(data.azurerm_subscription.current.id), 0, 13)`
   as the primary suffix generator to match Bicep's `uniqueString(subscription().subscriptionId)`
   exactly for any resource whose name must be identical across IaC flavors
   (e.g., Key Vault). Random suffix used only for resources where cross-flavor parity
   is not required. **OPEN: confirm whether Bicep and Terraform deployments are ever
   expected to target the same subscription simultaneously** — if so, global unique
   names (storage, KV) will collide and names must diverge by design.
6. Add `azure.yaml` with `infra.provider: terraform`, `infra.path: .`,
   preprovision/postprovision hook bindings (posix→`.sh`, windows→`.ps1`).
   **Do NOT set `infra.module`** — it is a Bicep-only field (points to `main.bicep`
   filename). azd Terraform uses the root directory as the module.
7. **Enable azd Terraform alpha**: add `azd config set alpha.terraform on` as the
   first step of the preprovision hook (idempotent; matches documented azd
   requirement for TF provider support).

## Phase 2 — Management Group bootstrap (`infra/terraform/smb-ready-foundation-mg/`)

_Parallel with Phase 1._ Must run BEFORE main root.

1. `azurerm_management_group.smb_rf` + `azurerm_management_group_subscription_association`.
2. Port `modules/policy-assignments-mg.bicep` → 30 discrete
   `azurerm_management_group_policy_assignment` resources keyed by the existing
   Bicep resource names (`policy_compute_01` … `policy_tagging_01`). Use `for_each`
   over a **rich** policy-map whose value shape is:
   `{ definition_id, display_name, description, parameters (object), enforcement_mode,
identity_type (None|SystemAssigned), role_definition_ids (list), non_compliance_message }`.
   Assignments whose shape diverges meaningfully from the uniform map (e.g., policies
   with resource-type selectors, nested policy parameters, or DeployIfNotExists-only
   properties) are lifted OUT of the map into individual resource blocks. Target:
   ≥ 80% via `for_each`, remainder as explicit blocks. Do not pretend one-map-fits-all.
3. Variables: `management_group_name`, `subscription_id`, `allowed_locations`,
   `allowed_vm_skus` (33 SKUs matching Bicep exactly — value-identical list).
4. Outputs: `management_group_id`.
5. Independent state file: `smb-ready-foundation-mg.tfstate`.
6. **Idempotency**: the MG may already exist (created previously by Bicep flow).
   Import path via `import` block (TF 1.5+) keyed by MG id
   `/providers/Microsoft.Management/managementGroups/smb-rf`. The import block is
   no-op when resource matches, creates-on-first-apply otherwise.
7. **Providers block**: `provider "azurerm" { features {} subscription_id = var.subscription_id }`
   required even for MG-only operations (TF azurerm 4.x mandates subscription_id).
   Add `data.azurerm_client_config.current` for tenant lookup.

## Phase 3 — Main root module composition (`infra/terraform/smb-ready-foundation/main.tf`)

_Depends on Phase 1._ Mirrors `main.bicep` phases exactly:

1. **Phase 3a — Subscription-scope**: budget (`azurerm_consumption_budget_subscription`
   — no AVM-TF module exists for consumption budgets), Defender pricings
   (`azurerm_security_center_subscription_pricing`).
2. **Phase 3b — Resource groups**: `Azure/avm-res-resources-resourcegroup/azurerm` ×6
   (hub, spoke, monitor, backup, migrate, security) via `for_each` on `rg_names` map.
3. **Phase 3c — Core networking**: hub VNet module + spoke VNet module (see Phase 4).
4. **Phase 3d — Supporting services**: monitoring, backup, migrate, keyvault, automation
   (see Phase 4).
5. **Phase 3e — Optional**: `module.firewall`, `module.route_tables`, `module.vpn_gateway`
   — gated via `count = var.deploy_firewall ? 1 : 0` (TF 1.5+ supports module-level
   `count`). Enforce VPN-after-Firewall ordering via explicit
   `depends_on = [module.firewall]` (ADR-0004 race condition).
6. **Phase 3f — Peering**: `module.networking_peering` gated on
   `local.deploy_peering`. When VPN is deployed, wire
   `depends_on = [module.vpn_gateway]`. To avoid the "unknown count at plan time"
   pitfall with conditional modules, insert a `terraform_data` relay resource
   (`resource "terraform_data" "vpn_ready" { triggers_replace = [module.vpn_gateway[*].id] }`)
   and `depends_on = [terraform_data.vpn_ready]` on peering. This guarantees
   correct ordering regardless of conditional module instantiation.

## Phase 4 — Child modules (`infra/terraform/smb-ready-foundation/modules/`)

_Parallel sub-tasks._ One child module per Bicep module. Preserve resource names
and outputs 1:1 with Bicep. Modules marked † **must be verified in the Phase 1
AVM-TF availability gate** — if the AVM module does not exist or lacks required
features, fall back to the raw-resource approach noted and record in the
TF-variant resource-inventory artifact.

| Bicep module               | TF module approach                                                                                                                                                  |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `resource-groups.bicep`    | `Azure/avm-res-resources-resourcegroup/azurerm` (inline in root via `for_each`) †                                                                                   |
| `networking-hub.bicep`     | `Azure/avm-res-network-virtualnetwork` + `...-networksecuritygroup` + `...-privatednszone` †                                                                        |
| `networking-spoke.bicep`   | Same VNet+NSG AVM; `Azure/avm-res-network-natgateway` (conditional) †                                                                                               |
| `firewall.bicep`           | `Azure/avm-res-network-publicipaddress` ×2 + `...-firewallpolicy` + `...-azurefirewall` †                                                                           |
| `route-tables.bicep`       | `Azure/avm-res-network-routetable` † (fallback: `azurerm_route_table` + `azurerm_route`)                                                                            |
| `vpn-gateway.bicep`        | `Azure/avm-res-network-virtualnetworkgateway` † (fallback: `azurerm_virtual_network_gateway`)                                                                       |
| `networking-peering.bicep` | `azurerm_virtual_network_peering` ×2 (hub→spoke, spoke→hub) — raw; no mature AVM                                                                                    |
| `monitoring.bicep`         | `Azure/avm-res-operationalinsights-workspace` with `daily_quota_gb` (number, not string) †                                                                          |
| `backup.bicep`             | `Azure/avm-res-recoveryservices-vault` † + `azurerm_backup_policy_vm` (AVM policy coverage partial)                                                                 |
| `policy-backup-auto.bicep` | `azurerm_subscription_policy_assignment` with SystemAssigned identity + 2× `azurerm_role_assignment` (Backup Contributor, Virtual Machine Contributor) at sub scope |
| `migrate.bicep`            | `azapi_resource` (`Microsoft.Migrate/assessmentProjects`) — no AVM-TF (Q2 decision)                                                                                 |
| `keyvault.bicep`           | `Azure/avm-res-keyvault-vault` † with PE + DNS zone + diagnostic settings; mirror Bicep's `purge_protection_enabled` and `soft_delete_retention_days`               |
| `defender.bicep`           | `azurerm_security_center_subscription_pricing` ×N — no AVM                                                                                                          |
| `automation.bicep`         | `Azure/avm-res-automation-automationaccount` † + `azurerm_log_analytics_linked_service` (fallback: `azurerm_automation_account`)                                    |
| `budget.bicep`             | `azurerm_consumption_budget_subscription` with 3 forecast thresholds (80/100/120%)                                                                                  |

Legacy note: `modules/policy-assignments.bicep` is **not** ported. Per Bicep
comments and the MG module header ("30 MG-scoped policies + 3 sub-scoped"), all
policies have been migrated to the MG module (Phase 2) and the 3 sub-scoped
assignments live in `policy-backup-auto.bicep`, `budget.bicep`, and `defender.bicep`.
Confirm during Phase 1 by searching for lingering references to
`policy-assignments.bicep` in `main.bicep`; if unreferenced, no port needed.

Every module enforces: required tags, diagnostic settings → LA workspace, TLS 1.2,
HTTPS-only, no public blob, `allow_shared_key_access = false` on storage, managed
identity where applicable.

## Phase 5 — Variables & parameter mapping

1. `variables.tf` — **per-feature booleans are the authoritative input surface**:
   `deploy_firewall` (bool), `deploy_vpn` (bool). There is **no** `scenario`
   input variable. For human labeling/cost summary, compute a derived local:
   `local.scenario = var.deploy_firewall && var.deploy_vpn ? "full" : var.deploy_firewall ? "firewall" : var.deploy_vpn ? "vpn" : "baseline"`.
   The preprovision hook reads azd's `SCENARIO` env var (for parity with Bicep
   partner UX) and **translates it** into `TF_VAR_deploy_firewall`/`TF_VAR_deploy_vpn`
   exports — no TF-side scenario variable required.
2. Port all Bicep params with correct TF types:
   - `location` (string, validation: allowed list)
   - `environment` (string, validation: `dev|staging|prod`)
   - `owner` (string, required)
   - `hub_vnet_address_space` (string, CIDR regex validation)
   - `spoke_vnet_address_space` (string, CIDR regex validation)
   - `on_premises_address_space` (string, optional, CIDR regex or empty)
   - `log_analytics_daily_cap_gb` (**number**, default `0.5` — NOT string; Bicep
     string `'0.5'` was a JSON-schema artifact, `azurerm_log_analytics_workspace.daily_quota_gb` requires a number)
   - `budget_amount` (number, validation: 100–10000)
   - `budget_alert_email` (string, default = `var.owner`)
   - `budget_start_date` (string, **no default** — injected at apply time from the
     hook as `TF_VAR_budget_start_date=$(date -u +%Y-%m-01)` to avoid `timestamp()`
     drift causing perpetual recreate)
3. Use TF `validation` blocks to replace Bicep `@allowed` / `@minValue` / `@maxValue`.
4. Add `precondition` blocks on key resources for CIDR overlap detection (defense
   in depth; the hook already fails hard on overlap before TF runs).
5. `terraform.tfvars.example` with boolean combinations documented and a mapping
   table from `SCENARIO` name to booleans for partner reference.
6. **azd → TF_VAR bridge**: preprovision hook exports the following before calling
   `terraform apply`:
   `TF_VAR_owner`, `TF_VAR_location`, `TF_VAR_environment`,
   `TF_VAR_hub_vnet_address_space`, `TF_VAR_spoke_vnet_address_space`,
   `TF_VAR_on_premises_address_space`, `TF_VAR_log_analytics_daily_cap_gb`,
   `TF_VAR_budget_amount`, `TF_VAR_budget_alert_email`, `TF_VAR_budget_start_date`,
   `TF_VAR_deploy_firewall`, `TF_VAR_deploy_vpn`.
   Values sourced from azd env vars (`SCENARIO`, `OWNER`, `AZURE_LOCATION`, etc.).
   azd itself only auto-bridges `AZURE_ENV_NAME`, `AZURE_LOCATION`, `AZURE_SUBSCRIPTION_ID`
   to `TF_VAR_*`, so the hook must handle everything else. (This replaces
   `main.parameters.json` from Bicep.)

## Phase 6 — Hooks (PowerShell **and** Bash, 1:1 parity with Bicep hooks)

Per Q3 decision, both OS variants exist and do the same work. Shared logic
extracted to helper files to minimize drift.

1. **Hook files**:
   - `hooks/pre-provision.sh` + `hooks/pre-provision.ps1`
   - `hooks/post-provision.sh` + `hooks/post-provision.ps1`
   - `hooks/_lib.sh` + `hooks/_lib.ps1` — shared CIDR, cleanup, retry helpers
2. **Preprovision responsibilities** (mirror `pre-provision.ps1`):
   - `azd config set alpha.terraform on` (idempotent, enables TF provider support)
   - Validate/auto-detect `OWNER`, `AZURE_LOCATION`, `SCENARIO`, CIDRs
   - Derive script-relative paths:
     Bash — `PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`,
     `MG_DIR="$(dirname "$PROJECT_DIR")/smb-ready-foundation-mg"`;
     PS — `$ProjectDir = Split-Path $PSScriptRoot -Parent; $MgDir = Join-Path (Split-Path $ProjectDir -Parent) 'smb-ready-foundation-mg'`.
     Never rely on the working directory; azd sets cwd inconsistently across versions.
   - CIDR overlap + prefix validation (duplicated across lib files; shared regex in `_lib.*`)
   - Run backend bootstrap: `scripts/bootstrap-tf-backend.{sh,ps1}` when
     `TF_BACKEND=azurerm`
   - Translate `SCENARIO` env var into `TF_VAR_deploy_firewall` and
     `TF_VAR_deploy_vpn` exports
   - Compute and export `TF_VAR_budget_start_date="$(date -u +%Y-%m-01)"`
     (avoids `timestamp()` drift in TF config)
   - Export all other `TF_VAR_*` values from azd env vars (Phase 5 step 6 list)
   - `terraform -chdir="$MG_DIR" init -backend-config="$MG_DIR/backend.hcl"`
     then `terraform -chdir="$MG_DIR" apply -auto-approve` to bootstrap MG + 30 policies
   - Delete stale budget (Azure API limitation — no TF equivalent)
   - Faulted firewall / VPN gateway cleanup via `az`
   - Orphaned role-assignment cleanup
3. **Postprovision responsibilities** (mirror `post-provision.ps1`):
   - Parse `terraform output -json`, print scenario summary, cost estimate, next steps
   - **Retry policy**: Bicep hook retries with 9 transient-error regex patterns and
     exponential backoff. Terraform equivalent — if `azd provision` fails, the
     postprovision hook detects via exit code / latest state, matches the same regex
     set against captured stderr from a `TF_LOG=ERROR` tail, and re-runs
     `terraform -chdir=<root> apply -auto-approve` with exponential backoff
     (3 attempts, 30/60/120s). Maintains parity with ADR-documented behavior.
4. **Terraform-native guards layered on top** (defense-in-depth, not replacement):
   - CIDR validation → `variable.validation` in addition to hook-level check
   - Scope enforcement → `precondition` on peering module (requires hub/spoke VNet IDs)
   - Scenario invariants → `precondition` blocks on firewall/vpn modules asserting
     the respective boolean is set. (Note: `check` blocks in TF 1.5+ only emit
     warnings and never fail apply; use `precondition` for blocking assertions.
     `check` is acceptable only for drift signaling in `terraform plan` output.)
5. **azd manifest hook routing**: `posix` → `.sh`, `windows` → `.ps1`. Both shells
   declared `pwsh` where the file is PS, `sh` where Bash. Match the existing Bicep
   manifest convention for drop-in familiarity.

## Phase 7 — State backend switching

1. `backend.tf` uses partial config: `backend "azurerm" {}` block with fields supplied
   via `-backend-config=...` during `terraform init`.
2. `hooks/pre-provision.{sh,ps1}` reads `TF_BACKEND` env var:
   - `TF_BACKEND=azurerm` (default) → ensure backend storage account exists
     (bootstrap via `az storage account create`), write `backend.hcl`
   - `TF_BACKEND=local` → skip bootstrap, init with
     `-backend-config=path=terraform.tfstate`
3. Backend bootstrap helpers: `scripts/bootstrap-tf-backend.sh` and
   `scripts/bootstrap-tf-backend.ps1` (idempotent SA creation). Backend SA lives in
   a dedicated RG `rg-tfstate-smb-<regionShort>` with storage firewall + blob
   versioning enabled.
4. Backend config values (SA name, container, key) derived from
   `AZURE_ENV_NAME` + subscription id suffix; `key` differs for `smb-ready-foundation`
   vs. `smb-ready-foundation-mg` so state files never collide.

## Phase 8 — CI / validation

1. Confirm `scripts/validate-terraform.mjs` (invoked by `npm run validate:terraform`
   and `npm run validate:_external`) already iterates `infra/terraform/*/`; if it
   does, both new roots are picked up automatically. If not, patch it.
2. Extend `scripts/diff-based-push-check.sh` so edits under
   `infra/terraform/smb-ready-foundation{,-mg}/**/*.tf` trigger `terraform fmt -check`,
   `terraform validate`, and `tflint` on the changed root(s). This matches the
   repo's diff-based pre-push convention.
3. Add GitHub Actions workflow
   `.github/workflows/terraform-smb-ready-foundation.yml`:
   fmt check, `terraform init -backend=false`, `validate`, `tflint`, plan on PR.
   Runs for paths `infra/terraform/smb-ready-foundation{,-mg}/**`.
4. Add e2e job (gated on label `e2e:terraform` or manual dispatch): OIDC federated
   login, `azd up` in ephemeral sub, assert resources via `az` queries, `azd down`.
   Matrix over 4 boolean combinations: `(false,false)`, `(true,false)`, `(false,true)`,
   `(true,true)` — equivalent to baseline/firewall/vpn/full.
5. Write `.tftest.hcl` files per module (mocked `azurerm` provider via
   `mock_provider`) for the most critical modules: `networking-hub`, `networking-spoke`,
   `firewall`, `vpn-gateway`, `networking-peering`, `keyvault`. Target: ≥ 1
   plan-mode assertion per module.
6. Add `iac-security-baseline` validation coverage for TF paths
   (`npm run validate:iac-security-baseline`); confirm the script's glob covers
   `infra/terraform/**/*.tf`.

## Phase 9 — Cleanup & teardown scripts

Scripts live at `infra/terraform/smb-ready-foundation/scripts/` (project-local,
mirroring Bicep's `infra/bicep/smb-ready-foundation/scripts/`). This prevents
collision with the Bicep teardown scripts.

1. `scripts/remove-smb-ready-foundation.sh` (Bash) and
   `scripts/Remove-SmbReadyFoundation.ps1` (PS) — both call
   `terraform destroy -auto-approve` in the main root, then the MG root in reverse
   order. Post-destroy steps: `az keyvault purge` for any KV with purge-protection,
   `az backup vault backup-item` cleanup for Recovery Services Vault soft-deleted
   items, orphaned role-assignment sweep (mirrors preprovision behavior).
2. `scripts/remove-smb-ready-foundation-policies.sh` and
   `scripts/Remove-SmbReadyFoundationPolicies.ps1` — destroy on
   `smb-ready-foundation-mg` root only (policies without touching MG or infra).
3. Key Vault module sets `purge_protection_enabled` and `soft_delete_retention_days`
   matching the Bicep values; teardown script is aware and calls
   `az keyvault purge --name <kv>` after TF destroy succeeds.

## Phase 10 — Agent-output artifacts (Terraform variants, new files only)

Create new files alongside existing Bicep artifacts. Do **not** touch existing files.

1. `agent-output/smb-ready-foundation/04-implementation-plan-terraform.md` —
   TF-specific implementation plan (mirror structure of `04-implementation-plan.md`).
2. `agent-output/smb-ready-foundation/05-implementation-reference-terraform.md` —
   TF code reference index.
3. `agent-output/smb-ready-foundation/07-ab-adr-0005-terraform-implementation.md` —
   ADR documenting TF port decisions (AVM-TF, dual backend, MG bootstrap split, etc.).
4. `agent-output/smb-ready-foundation/07-ab-adr-0006-terraform-hook-modernization.md` —
   ADR on native-guard vs. PS hooks.
5. `agent-output/smb-ready-foundation/07-resource-inventory-terraform.md` —
   TF resource inventory (side-by-side with Bicep inventory).
6. Update `agent-output/smb-ready-foundation/README.md` to add a **new section** only
   (no modifications to existing content) pointing to the TF variants.

---

## Relevant files (reference templates to reuse)

- `infra/bicep/smb-ready-foundation/main.bicep` — orchestration phases, scenario logic,
  cross-module wiring; direct 1:1 translation target for `main.tf`
- `infra/bicep/smb-ready-foundation/modules/*.bicep` — per-module source of truth
- `infra/bicep/smb-ready-foundation/hooks/pre-provision.ps1` — preprovision behavior
  contract (CIDR, MG, cleanup, retry); guides `hooks/pre-provision.sh`
- `infra/bicep/smb-ready-foundation/hooks/post-provision.ps1` — postprovision UX
- `infra/bicep/smb-ready-foundation/azure.yaml` — azd manifest template
- `infra/bicep/smb-ready-foundation/modules/policy-assignments-mg.bicep` — 30 policy
  assignments to replicate in `smb-ready-foundation-mg`
- `infra/bicep/smb-ready-foundation/deploy-mg.bicep` — MG bootstrap target
- `.github/skills/terraform-patterns/SKILL.md` + `references/` — AVM-TF patterns,
  conditional deployment, private endpoints, diagnostic settings
- `.github/instructions/iac-terraform-best-practices.instructions.md` — style guide
- `AGENTS.md` — repo conventions (naming, tags, provider pins, AVM-first)

## Verification

1. `terraform fmt -check -recursive infra/terraform/` passes
2. `cd infra/terraform/smb-ready-foundation && terraform init -backend=false && terraform validate` passes
3. `cd infra/terraform/smb-ready-foundation-mg && terraform init -backend=false && terraform validate` passes
4. `tflint --init && tflint` passes in both roots
5. `npm run validate:terraform` passes
6. `npm run validate:iac-security-baseline` passes on TF paths
7. `terraform test` passes in each module with `.tftest.hcl`
8. End-to-end: set `azd env set OWNER <email>` + boolean combinations via
   `azd env set DEPLOY_FIREWALL <bool>` / `DEPLOY_VPN <bool>` (or use the
   `SCENARIO` shim) and run `azd up` for each of the 4 combinations:
   `(false,false)` baseline, `(true,false)` firewall, `(false,true)` vpn,
   `(true,true)` full. Each deploys cleanly
9. Policy count assertion: `az policy assignment list --scope /providers/Microsoft.Management/managementGroups/smb-rf --query "length(@)" -o tsv` equals **30**
10. Sub-scoped policy/budget/Defender assertion: `az policy assignment list --scope /subscriptions/<sub> --query "length([?starts_with(name, 'smb-')])" -o tsv` equals **3** (auto-backup, budget, Defender plans)
11. Side-by-side resource inventory (via `az resource list -g rg-hub-smb-swc -o table`) matches the Bicep deployment for the same scenario (resource type counts and tags)
12. Deployed resource tags (`Environment`, `Owner`, `Project`, `ManagedBy=Terraform`), names, and counts match the Bicep naming convention
13. `azd down` + teardown scripts leave no orphans (no soft-deleted KV, no orphaned role assignments, no leftover Public IPs from faulted VPN/Firewall)
14. CI workflow `terraform-smb-ready-foundation.yml` green on PR (fmt, validate, tflint, plan)

## Further considerations (residual risks flagged during planning)

1. **Shared-subscription naming collisions** — if Bicep and TF deployments ever target
   the same subscription at the same time, globally unique names (Key Vault, storage)
   will collide. Use per-flavor suffix (e.g., `${uniqueSuffix}t` for TF) or enforce
   mutually exclusive deployments. Recommendation: document as an operational
   constraint in the TF-variant README section; verify during Phase 1.
2. **AVM-TF maturity gate (Phase 1 step 4)** — modules marked † in the Phase 4 table
   are unverified. Expected gaps: `avm-res-migrate` (none — azapi), `avm-res-security-pricing`
   (none — azurerm), `consumption-budget` (none — azurerm), possibly
   `virtualnetworkgateway`, `route-table`, `automation-automationaccount`.
   Each gap triggers an `azurerm_*`/`azapi_*` fallback and an entry in the TF-variant
   resource-inventory artifact.
3. **MG bootstrap idempotency when MG already exists from Bicep flow** — `import`
   block chosen; must verify behavior for `Microsoft.Management/managementGroups`
   with scope `/providers/Microsoft.Management/managementGroups/smb-rf`. If import
   conflicts with Bicep-created MG, fall back to
   `data.azurerm_management_group` + conditional creation (`count = data.exists ? 0 : 1`).
4. **azd alpha.terraform churn** — azd's Terraform provider is marked alpha; field
   names (`infra.provider`, hook env-var bridging) can change between azd versions.
   Pin a minimum azd version in the project README and verify against it in CI.
5. **30 MG-scoped policy assignments — role assignments for DeployIfNotExists** —
   the policy-backup-auto policy requires a managed identity with Backup Contributor
   - VM Contributor roles. AVM-TF does not abstract this; must hand-code the
     system-assigned MI on the policy assignment and two
     `azurerm_role_assignment` resources at subscription scope. Covered in the Phase 4
     row for `policy-backup-auto.bicep`.
6. **Terraform hook retry semantics diverge from Bicep** — Bicep retry calls
   `az deployment sub create` directly; TF retry calls `terraform apply`. State
   mutations from a partial `apply` persist, which is fine for TF (idempotent) but
   means the error-pattern match may fire on stale stderr from a prior attempt.
   Mitigation: hook captures only the most-recent run's stderr; documented in
   ADR-0006 (TF hook modernization).
7. **`random_string` vs. `uniqueString(sub.id)` parity** — the sha1-based suffix
   reproduces Bicep's deterministic output only when the subscription id matches.
   For any resource whose Bicep-produced name relies on `uniqueString` of something
   other than subscription id (e.g., resource-group id), the TF port must replicate
   the exact input to `sha1()`. Audit every Bicep `uniqueString()` call site during
   Phase 1 and document the input in `locals.tf` comments.
