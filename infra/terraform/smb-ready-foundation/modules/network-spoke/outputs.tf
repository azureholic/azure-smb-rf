output "vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "vnet_name" {
  value = azurerm_virtual_network.spoke.name
}

output "workload_subnet_id" {
  value = azurerm_subnet.workload.id
}

output "data_subnet_id" {
  value = azurerm_subnet.data.id
}

output "app_subnet_id" {
  value = azurerm_subnet.app.id
}

output "pep_subnet_id" {
  value = azurerm_subnet.pep.id
}

output "workload_subnet_ids" {
  description = "Map of workload/data/app subnet ids for route-table + NAT associations."
  value       = local.workload_subnet_ids
}

output "nat_gateway_name" {
  description = "NAT gateway name (empty when disabled)."
  value       = var.deploy_nat_gateway ? azurerm_nat_gateway.spoke[0].name : ""
}
