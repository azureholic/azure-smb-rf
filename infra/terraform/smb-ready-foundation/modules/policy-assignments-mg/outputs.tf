output "assignment_count" {
  description = "Total number of MG-scoped policy assignments created by this module."
  value = (
    length(azurerm_management_group_policy_assignment.uniform) +
    length(azurerm_management_group_policy_assignment.kv_audit) +
    5
  )
}
