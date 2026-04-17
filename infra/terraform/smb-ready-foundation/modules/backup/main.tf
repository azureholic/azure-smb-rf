// Recovery Services Vault + DefaultVMPolicy.

locals {
  name = "rsv-smbrf-smb-${var.region_short}"
}

resource "azurerm_recovery_services_vault" "smbrf" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  sku                 = "Standard"
  soft_delete_enabled = true
  storage_mode_type   = "GeoRedundant"
}

resource "azurerm_backup_policy_vm" "default_vm" {
  name                = "DefaultVMPolicy"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.smbrf.name

  timezone                       = "UTC"
  instant_restore_retention_days = 2

  backup {
    frequency = "Daily"
    time      = "02:00"
  }

  retention_daily {
    count = 30
  }

  retention_weekly {
    count    = 12
    weekdays = ["Sunday"]
  }

  retention_monthly {
    count    = 12
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }
}
