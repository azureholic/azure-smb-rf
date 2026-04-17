// Hub networking — VNet + NSG + 4 subnets + shared Private DNS Zone.

locals {
  hub_prefix          = tonumber(split("/", var.address_space)[1])
  vnet_name           = "vnet-hub-smb-${var.region_short}"
  nsg_name            = "nsg-hub-smb-${var.region_short}"
  shared_pdz_name     = "privatelink.azure.com"
  afw_subnet_cidr     = cidrsubnet(var.address_space, 26 - local.hub_prefix, 0)
  afwmgmt_subnet_cidr = cidrsubnet(var.address_space, 26 - local.hub_prefix, 1)
  mgmt_subnet_cidr    = cidrsubnet(var.address_space, 26 - local.hub_prefix, 2)
  gw_subnet_cidr      = cidrsubnet(var.address_space, 27 - local.hub_prefix, 6)
}

resource "azurerm_network_security_group" "hub" {
  name                = local.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Default deny all inbound traffic"
  }
}

resource "azurerm_virtual_network" "hub" {
  name                = local.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  address_space       = [var.address_space]
}

resource "azurerm_subnet" "afw" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.afw_subnet_cidr]
}

resource "azurerm_subnet" "afw_mgmt" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.afwmgmt_subnet_cidr]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.gw_subnet_cidr]
}

resource "azurerm_subnet" "management" {
  name                 = "snet-management"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [local.mgmt_subnet_cidr]
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.hub.id
}

resource "azurerm_private_dns_zone" "shared" {
  name                = local.shared_pdz_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "shared_hub" {
  name                  = "link-${local.vnet_name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.shared.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = true
  tags                  = var.tags
}
