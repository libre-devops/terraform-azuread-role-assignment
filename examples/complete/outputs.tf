output "activated_directory_role_template_ids" {
  description = "Template ids of the activated built-in directory roles."
  value       = module.role_assignment.activated_directory_role_template_ids
}

output "custom_directory_role_object_ids" {
  description = "Object ids of the custom directory roles."
  value       = module.role_assignment.custom_directory_role_object_ids
}

output "role_assignment_ids" {
  description = "Ids of the directory role assignments."
  value       = module.role_assignment.role_assignment_ids
}
