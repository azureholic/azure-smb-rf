output "vault_id" {
  value = azurerm_recovery_services_vault.smbrf.id
}

output "vault_name" {
  value = azurerm_recovery_services_vault.smbrf.name
}

output "default_vm_policy_id" {
  description = "Composite policy ID for use by policy-backup-auto (mirrors Bicep string concat)."
  value       = "${azurerm_recovery_services_vault.smbrf.id}/backupPolicies/${azurerm_backup_policy_vm.default_vm.name}"
}
