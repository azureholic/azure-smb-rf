// Azure Automation Account linked to Log Analytics.

locals {
  name = "aa-smbrf-smb-${var.region_short}"
}

resource "azurerm_automation_account" "smbrf" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  sku_name                      = "Basic"
  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_log_analytics_linked_service" "automation" {
  resource_group_name = var.resource_group_name
  workspace_id        = var.log_analytics_workspace_id
  read_access_id      = azurerm_automation_account.smbrf.id
}

resource "azurerm_monitor_diagnostic_setting" "aa" {
  name                       = "aa-diag-law"
  target_resource_id         = azurerm_automation_account.smbrf.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
