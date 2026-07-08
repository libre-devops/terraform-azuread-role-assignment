output "activated_directory_role_object_ids" {
  description = "Map of activated built-in directory role key to its object id."
  value       = { for k, v in azuread_directory_role.this : k => v.object_id }
}

output "activated_directory_role_template_ids" {
  description = "Map of activated built-in directory role key to its template id (the value used when assigning a built-in role)."
  value       = { for k, v in azuread_directory_role.this : k => v.template_id }
}

output "custom_directory_role_object_ids" {
  description = "Map of custom directory role key to its object id (the value used when assigning a custom role)."
  value       = { for k, v in azuread_custom_directory_role.this : k => v.object_id }
}

output "custom_directory_roles" {
  description = "Map of custom directory role key to its useful attributes."
  value = {
    for k, v in azuread_custom_directory_role.this : k => {
      object_id    = v.object_id
      display_name = v.display_name
      enabled      = v.enabled
      version      = v.version
    }
  }
}

output "role_assignment_ids" {
  description = "Map of role assignment key to the directory role assignment id."
  value       = { for k, v in azuread_directory_role_assignment.this : k => v.id }
}
