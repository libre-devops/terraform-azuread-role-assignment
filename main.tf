data "azuread_client_config" "current" {}

# Activate built-in directory roles from their templates so they can be assigned. Activation is
# idempotent and, per the provider, roles cannot be deactivated, so destroy is a no-op for these.
resource "azuread_directory_role" "this" {
  for_each = var.activated_directory_roles

  display_name = each.value.display_name
  template_id  = each.value.template_id
}

# Custom directory roles.
resource "azuread_custom_directory_role" "this" {
  for_each = var.custom_directory_roles

  display_name = each.value.display_name
  description  = each.value.description
  enabled      = each.value.enabled
  version      = each.value.version
  template_id  = each.value.template_id

  dynamic "permissions" {
    for_each = each.value.permissions
    content {
      allowed_resource_actions = permissions.value.allowed_resource_actions
    }
  }
}

# Role assignments. Built-in roles are referenced by template id, custom roles by object id; the
# raw role_id escape hatch takes either. The exactly-one-reference rule is enforced by variable
# validation, so precisely one branch resolves.
resource "azuread_directory_role_assignment" "this" {
  for_each = var.role_assignments

  role_id = (
    each.value.role_id != null ? each.value.role_id :
    each.value.custom_role_key != null ? azuread_custom_directory_role.this[each.value.custom_role_key].object_id :
    azuread_directory_role.this[each.value.directory_role_key].template_id
  )
  principal_object_id = each.value.principal_object_id
  app_scope_id        = each.value.app_scope_id
  directory_scope_id  = each.value.directory_scope_id
}
