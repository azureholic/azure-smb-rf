// Key Vault — RBAC + soft delete + purge protection + private endpoint + diag.

locals {
  kv_name  = "kv-smbrf-${var.region_short}-${substr(var.unique_suffix, 0, 8)}"
  pep_name = "pep-kv-smbrf-smb-${var.region_short}"
  pdz_name = "privatelink.vaultcore.azure.net"
}

resource "azurerm_key_vault" "smbrf" {
  name                = local.kv_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  tenant_id = var.tenant_id
  sku_name  = "standard"

  enable_rbac_authorization     = true
  soft_delete_retention_days    = 90
  purge_protection_enabled      = true
  public_network_access_enabled = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }
}

resource "azurerm_private_dns_zone" "kv" {
  name                = local.pdz_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_endpoint" "kv" {
  name                = local.pep_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  subnet_id           = var.pep_subnet_id

  private_service_connection {
    name                           = "psc-${local.kv_name}"
    private_connection_resource_id = azurerm_key_vault.smbrf.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv.id]
  }
}

resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "kv-diag-law"
  target_resource_id         = azurerm_key_vault.smbrf.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
