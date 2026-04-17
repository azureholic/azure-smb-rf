output "vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "afw_subnet_id" {
  value = azurerm_subnet.afw.id
}

output "afw_mgmt_subnet_id" {
  value = azurerm_subnet.afw_mgmt.id
}

output "gateway_subnet_id" {
  value = azurerm_subnet.gateway.id
}

output "management_subnet_id" {
  value = azurerm_subnet.management.id
}

output "shared_private_dns_zone_id" {
  value = azurerm_private_dns_zone.shared.id
}
