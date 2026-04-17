output "id" {
  description = "Firewall resource ID (empty when disabled)."
  value       = var.enabled ? azurerm_firewall.hub[0].id : ""
}

output "private_ip" {
  description = "Private IP of the firewall data interface (empty when disabled)."
  value       = var.enabled ? azurerm_firewall.hub[0].ip_configuration[0].private_ip_address : ""
}
