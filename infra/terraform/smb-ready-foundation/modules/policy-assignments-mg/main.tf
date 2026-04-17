// MG-scoped Azure Policy assignments (33 total)
// Mirrors infra/bicep/smb-ready-foundation/modules/policy-assignments-mg.bicep.

locals {
  policy_definitions = {
    allowedVmSkus             = "/providers/Microsoft.Authorization/policyDefinitions/cccc23c7-8427-4f53-ad12-b6a63eb452b3"
    noPublicIpOnNic           = "/providers/Microsoft.Authorization/policyDefinitions/83a86a26-fd1f-447c-b59d-e51f44264114"
    auditManagedDisks         = "/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d"
    auditArmVms               = "/providers/Microsoft.Authorization/policyDefinitions/1d84d5fb-01f6-4d12-ba4f-4a26081d403d"
    auditSystemUpdates        = "/providers/Microsoft.Authorization/policyDefinitions/86b3d65f-7626-441e-b690-81a8b71cff60"
    auditEndpointProtection   = "/providers/Microsoft.Authorization/policyDefinitions/26a828e1-e88f-464e-bbb3-c134a282b9de"
    nsgOnSubnets              = "/providers/Microsoft.Authorization/policyDefinitions/e71308d3-144b-4262-b144-efdc3cc90517"
    closeManagementPorts      = "/providers/Microsoft.Authorization/policyDefinitions/22730e10-96f6-4aac-ad84-9383d35b5917"
    restrictNsgPorts          = "/providers/Microsoft.Authorization/policyDefinitions/9daedab3-fb2d-461e-b861-71790eead4f6"
    disableIpForwarding       = "/providers/Microsoft.Authorization/policyDefinitions/88c0b9da-ce96-4b03-9635-f29a937e2900"
    nsgFlowLogs               = "/providers/Microsoft.Authorization/policyDefinitions/27960feb-a23c-4577-8d36-ef8b5f35e0be"
    storageHttpsOnly          = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
    noPublicBlobAccess        = "/providers/Microsoft.Authorization/policyDefinitions/4fa4b6c0-31ca-4c0d-b10d-24b96f62a751"
    storageTls12              = "/providers/Microsoft.Authorization/policyDefinitions/fe83a0eb-a853-422d-aac2-1bffd182c5d0"
    restrictStorageNetwork    = "/providers/Microsoft.Authorization/policyDefinitions/34c877ad-507e-4c82-993e-3452a6e0ad3c"
    storageArmMigration       = "/providers/Microsoft.Authorization/policyDefinitions/37e0d2fe-28a5-43d6-a273-67d37d1f5606"
    auditStorageGeoRedundancy = "/providers/Microsoft.Authorization/policyDefinitions/bf045164-79ba-4215-8f95-f8048dc1780b"
    sqlAzureAdOnly            = "/providers/Microsoft.Authorization/policyDefinitions/b3a22bc9-66de-45fb-98fa-00f5df42f41a"
    sqlNoPublicAccess         = "/providers/Microsoft.Authorization/policyDefinitions/1b8ca024-1d5c-4dec-8995-b1a932b41780"
    auditMfaOwners            = "/providers/Microsoft.Authorization/policyDefinitions/aa633080-8b72-40c4-a2d7-d00c03e80bed"
    auditDeprecatedAccounts   = "/providers/Microsoft.Authorization/policyDefinitions/8d7e1fde-fe26-4b5f-8108-f8e432cbc2be"
    requireTag                = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
    allowedLocations          = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
    vmBackupRequired          = "/providers/Microsoft.Authorization/policyDefinitions/013e242c-8828-4970-87b3-ab247555486d"
    diagnosticSettings        = "/providers/Microsoft.Authorization/policyDefinitions/7f89b1eb-583c-429a-8828-af049802c1d9"
    kvSoftDelete              = "/providers/Microsoft.Authorization/policyDefinitions/1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d"
    kvDeletionProtection      = "/providers/Microsoft.Authorization/policyDefinitions/0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
    kvRbacModel               = "/providers/Microsoft.Authorization/policyDefinitions/12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5"
    kvNoPublicNetwork         = "/providers/Microsoft.Authorization/policyDefinitions/405c5871-3e91-4644-8a63-58e19d68ff5b"
    kvSecretsExpiration       = "/providers/Microsoft.Authorization/policyDefinitions/98728c90-32c7-4049-8429-847dc0f4fe37"
    kvKeysExpiration          = "/providers/Microsoft.Authorization/policyDefinitions/152b15f7-8e1f-4c1f-ab71-8c010ba5dbc0"
    kvResourceLogs            = "/providers/Microsoft.Authorization/policyDefinitions/cf820ca0-f99e-4f3e-84fb-66e913812d21"
  }

  uniform_policy_assignments = {
    "smb-compute-02"  = { display_name = "SMB LZ: No Public IPs on NICs", description = "Prevent VMs from having public IP addresses for security", policy_definition = local.policy_definitions.noPublicIpOnNic }
    "smb-compute-03"  = { display_name = "SMB LZ: Audit Managed Disks", description = "Audit VMs that do not use managed disks", policy_definition = local.policy_definitions.auditManagedDisks }
    "smb-compute-04"  = { display_name = "SMB LZ: Audit ARM VMs", description = "Audit VMs created using classic deployment model", policy_definition = local.policy_definitions.auditArmVms }
    "smb-compute-05"  = { display_name = "SMB LZ: Audit System Updates on VMs", description = "Audit VMs that are missing system updates", policy_definition = local.policy_definitions.auditSystemUpdates }
    "smb-compute-06"  = { display_name = "SMB LZ: Audit Endpoint Protection", description = "Audit VMs that do not have endpoint protection installed", policy_definition = local.policy_definitions.auditEndpointProtection }
    "smb-network-01"  = { display_name = "SMB LZ: NSG on Subnets", description = "Audit subnets that do not have a Network Security Group", policy_definition = local.policy_definitions.nsgOnSubnets }
    "smb-network-02"  = { display_name = "SMB LZ: Close Management Ports", description = "Audit VMs with management ports (22, 3389) exposed to the internet", policy_definition = local.policy_definitions.closeManagementPorts }
    "smb-network-03"  = { display_name = "SMB LZ: Restrict NSG Ports", description = "Audit NSG rules that allow unrestricted access", policy_definition = local.policy_definitions.restrictNsgPorts }
    "smb-network-04"  = { display_name = "SMB LZ: Disable IP Forwarding", description = "Deny enabling IP forwarding on network interfaces", policy_definition = local.policy_definitions.disableIpForwarding }
    "smb-network-05"  = { display_name = "SMB LZ: Audit NSG Flow Logs", description = "Audit Network Security Groups that do not have flow logs configured", policy_definition = local.policy_definitions.nsgFlowLogs }
    "smb-storage-01"  = { display_name = "SMB LZ: Storage HTTPS Only", description = "Deny storage accounts that do not require HTTPS", policy_definition = local.policy_definitions.storageHttpsOnly }
    "smb-storage-02"  = { display_name = "SMB LZ: No Public Blob Access", description = "Deny public blob access on storage accounts", policy_definition = local.policy_definitions.noPublicBlobAccess }
    "smb-storage-03"  = { display_name = "SMB LZ: Storage TLS 1.2", description = "Deny storage accounts with minimum TLS version below 1.2", policy_definition = local.policy_definitions.storageTls12 }
    "smb-storage-04"  = { display_name = "SMB LZ: Restrict Storage Network", description = "Audit storage accounts with unrestricted network access", policy_definition = local.policy_definitions.restrictStorageNetwork }
    "smb-storage-05"  = { display_name = "SMB LZ: Storage ARM Migration", description = "Audit classic storage accounts that should be migrated to ARM", policy_definition = local.policy_definitions.storageArmMigration }
    "smb-identity-01" = { display_name = "SMB LZ: SQL Azure AD Only", description = "Audit SQL servers that do not use Azure AD-only authentication", policy_definition = local.policy_definitions.sqlAzureAdOnly }
    "smb-identity-02" = { display_name = "SMB LZ: SQL No Public Access", description = "Audit SQL servers with public network access enabled", policy_definition = local.policy_definitions.sqlNoPublicAccess }
    "smb-identity-03" = { display_name = "SMB LZ: Audit MFA for Owners", description = "Audit accounts with owner permissions that do not have MFA enabled", policy_definition = local.policy_definitions.auditMfaOwners }
    "smb-identity-04" = { display_name = "SMB LZ: Audit Blocked Accounts", description = "Audit blocked accounts with read and write permissions on Azure resources", policy_definition = local.policy_definitions.auditDeprecatedAccounts }
    "smb-backup-01"   = { display_name = "SMB LZ: VM Backup Required", description = "Audit VMs that do not have backup configured", policy_definition = local.policy_definitions.vmBackupRequired }
    "smb-backup-03"   = { display_name = "SMB LZ: Audit Storage Geo-Redundancy", description = "Audit storage accounts that do not use geo-redundant storage", policy_definition = local.policy_definitions.auditStorageGeoRedundancy }
    "smb-kv-07"       = { display_name = "SMB LZ: Key Vault Resource Logs", description = "Audit Key Vaults that do not have resource logs enabled", policy_definition = local.policy_definitions.kvResourceLogs }
  }

  kv_audit_assignments = {
    "smb-kv-01" = { display_name = "SMB LZ: Key Vault Soft Delete", description = "Audit Key Vaults that do not have soft delete enabled", policy_definition = local.policy_definitions.kvSoftDelete }
    "smb-kv-02" = { display_name = "SMB LZ: Key Vault Deletion Protection", description = "Audit Key Vaults without purge protection and soft delete", policy_definition = local.policy_definitions.kvDeletionProtection }
    "smb-kv-03" = { display_name = "SMB LZ: Key Vault RBAC Model", description = "Audit Key Vaults that do not use RBAC permission model", policy_definition = local.policy_definitions.kvRbacModel }
    "smb-kv-04" = { display_name = "SMB LZ: Key Vault No Public Network", description = "Audit Key Vaults that have public network access enabled", policy_definition = local.policy_definitions.kvNoPublicNetwork }
    "smb-kv-05" = { display_name = "SMB LZ: Key Vault Secrets Expiration", description = "Audit secrets that do not have an expiration date set", policy_definition = local.policy_definitions.kvSecretsExpiration }
    "smb-kv-06" = { display_name = "SMB LZ: Key Vault Keys Expiration", description = "Audit keys that do not have an expiration date set", policy_definition = local.policy_definitions.kvKeysExpiration }
  }
}

resource "azurerm_management_group_policy_assignment" "uniform" {
  for_each = local.uniform_policy_assignments

  name                 = each.key
  display_name         = each.value.display_name
  description          = each.value.description
  policy_definition_id = each.value.policy_definition
  management_group_id  = var.management_group_id
  enforce              = true
  location             = var.assignment_location
}

resource "azurerm_management_group_policy_assignment" "kv_audit" {
  for_each = local.kv_audit_assignments

  name                 = each.key
  display_name         = each.value.display_name
  description          = each.value.description
  policy_definition_id = each.value.policy_definition
  management_group_id  = var.management_group_id
  enforce              = true
  location             = var.assignment_location

  parameters = jsonencode({
    effect = { value = "Audit" }
  })
}

resource "azurerm_management_group_policy_assignment" "compute_01_allowed_skus" {
  name                 = "smb-compute-01"
  display_name         = "SMB LZ: Allowed VM SKUs"
  description          = "Restrict VM deployments to cost-effective B-series and D/E v5/v6 series SKUs"
  policy_definition_id = local.policy_definitions.allowedVmSkus
  management_group_id  = var.management_group_id
  enforce              = true
  location             = var.assignment_location

  parameters = jsonencode({
    listOfAllowedSKUs = { value = var.allowed_vm_skus }
  })
}

resource "azurerm_management_group_policy_assignment" "tagging_01_environment" {
  name                 = "smb-tagging-01"
  display_name         = "SMB LZ: Require Environment Tag"
  description          = "Deny resource creation without Environment tag"
  policy_definition_id = local.policy_definitions.requireTag
  management_group_id  = var.management_group_id
  enforce              = true
  location             = var.assignment_location

  parameters = jsonencode({
    tagName = { value = "Environment" }
  })
}

resource "azurerm_management_group_policy_assignment" "tagging_02_owner" {
  name                 = "smb-tagging-02"
  display_name         = "SMB LZ: Require Owner Tag"
  description          = "Deny resource creation without Owner tag"
  policy_definition_id = local.policy_definitions.requireTag
  management_group_id  = var.management_group_id
  enforce              = true
  location             = var.assignment_location

  parameters = jsonencode({
    tagName = { value = "Owner" }
  })
}

resource "azurerm_management_group_policy_assignment" "governance_01_allowed_locations" {
  name                 = "smb-governance-01"
  display_name         = "SMB LZ: Allowed Locations"
  description          = "Restrict resource deployment to swedencentral, germanywestcentral, and global"
  policy_definition_id = local.policy_definitions.allowedLocations
  management_group_id  = var.management_group_id
  enforce              = true
  location             = var.assignment_location

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })
}

resource "azurerm_management_group_policy_assignment" "monitoring_01_diagnostics" {
  name                 = "smb-monitoring-01"
  display_name         = "SMB LZ: Diagnostic Settings Required"
  description          = "Audit resources that do not have diagnostic settings configured"
  policy_definition_id = local.policy_definitions.diagnosticSettings
  management_group_id  = var.management_group_id
  enforce              = true
  location             = var.assignment_location

  parameters = jsonencode({
    listOfResourceTypes = {
      value = [
        "Microsoft.Compute/virtualMachines",
        "Microsoft.Network/virtualNetworks",
        "Microsoft.Network/networkSecurityGroups",
        "Microsoft.Network/azureFirewalls",
        "Microsoft.Network/bastionHosts",
        "Microsoft.KeyVault/vaults",
        "Microsoft.RecoveryServices/vaults",
        "Microsoft.Sql/servers",
      ]
    }
  })
}
