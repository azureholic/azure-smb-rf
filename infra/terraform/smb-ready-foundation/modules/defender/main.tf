// Microsoft Defender for Cloud — Free tier, auto-provisioning Off.

locals {
  plans = ["VirtualMachines", "StorageAccounts", "KeyVaults", "Arm"]
}

resource "azurerm_security_center_subscription_pricing" "free" {
  for_each = toset(local.plans)

  tier          = "Free"
  resource_type = each.key
}

resource "azurerm_security_center_auto_provisioning" "off" {
  auto_provision = "Off"
}
