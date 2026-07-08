output "custom_directory_role_object_ids" {
  description = "Object ids of the custom directory roles, keyed by role name."
  value       = module.role_assignment.custom_directory_role_object_ids
}
