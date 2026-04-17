// Log Analytics Workspace.

locals {
  name           = "log-smbrf-smb-${var.region_short}"
  daily_quota_gb = var.daily_cap_gb > 0 ? var.daily_cap_gb : -1
}

resource "azurerm_log_analytics_workspace" "smbrf" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  sku               = "PerGB2018"
  retention_in_days = 30
  daily_quota_gb    = local.daily_quota_gb

  internet_ingestion_enabled = true
  internet_query_enabled     = true
}
