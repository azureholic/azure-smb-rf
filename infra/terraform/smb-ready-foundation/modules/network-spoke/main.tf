// Spoke networking — VNet + NSG + 4 subnets + conditional NAT gateway.

locals {
  spoke_prefix         = tonumber(split("/", var.address_space)[1])
  vnet_name            = "vnet-spoke-${var.environment}-${var.region_short}"
  nsg_name             = "nsg-spoke-${var.environment}-${var.region_short}"
  nat_name             = "nat-spoke-${var.environment}-${var.region_short}"
  nat_pip_name         = "pip-nat-${var.environment}-${var.region_short}"
  workload_subnet_cidr = cidrsubnet(var.address_space, 25 - local.spoke_prefix, 0)
  data_subnet_cidr     = cidrsubnet(var.address_space, 25 - local.spoke_prefix, 1)
  app_subnet_cidr      = cidrsubnet(var.address_space, 25 - local.spoke_prefix, 2)
  pep_subnet_cidr      = cidrsubnet(var.address_space, 26 - local.spoke_prefix, 6)
}

resource "azurerm_network_security_group" "spoke" {
  name                = local.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
    description                = "Allow inbound traffic within VNet"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancerInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
    description                = "Allow Azure Load Balancer health probes"
  }

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

resource "azurerm_virtual_network" "spoke" {
  name                = local.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  address_space       = [var.address_space]
}

resource "azurerm_public_ip" "nat" {
  count = var.deploy_nat_gateway ? 1 : 0

  name                = local.nat_pip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "spoke" {
  count = var.deploy_nat_gateway ? 1 : 0

  name                    = local.nat_name
  location                = var.location
  resource_group_name     = var.resource_group_name
  tags                    = var.tags
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
}

resource "azurerm_nat_gateway_public_ip_association" "spoke" {
  count = var.deploy_nat_gateway ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.spoke[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [local.workload_subnet_cidr]
}

resource "azurerm_subnet" "data" {
  name                 = "snet-data"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [local.data_subnet_cidr]
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [local.app_subnet_cidr]
}

resource "azurerm_subnet" "pep" {
  name                              = "snet-pep"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.spoke.name
  address_prefixes                  = [local.pep_subnet_cidr]
  private_endpoint_network_policies = "Disabled"
}

locals {
  workload_subnet_ids = {
    workload = azurerm_subnet.workload.id
    data     = azurerm_subnet.data.id
    app      = azurerm_subnet.app.id
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke" {
  for_each = local.workload_subnet_ids

  subnet_id                 = each.value
  network_security_group_id = azurerm_network_security_group.spoke.id
}

resource "azurerm_subnet_network_security_group_association" "pep" {
  subnet_id                 = azurerm_subnet.pep.id
  network_security_group_id = azurerm_network_security_group.spoke.id
}

resource "azurerm_subnet_nat_gateway_association" "spoke" {
  for_each = var.deploy_nat_gateway ? local.workload_subnet_ids : {}

  subnet_id      = each.value
  nat_gateway_id = azurerm_nat_gateway.spoke[0].id
}
