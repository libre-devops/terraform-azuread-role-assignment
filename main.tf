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

# ---------------------------------------------------------------------------------------------------
# Microsoft Graph application permission grants to existing principals (the managed-identity shape)
# ---------------------------------------------------------------------------------------------------

# Both data sources exist only when grants are requested, so grant-free calls make no Graph reads.
data "azuread_application_published_app_ids" "well_known" {
  count = length(var.graph_app_role_grants) > 0 ? 1 : 0
}

data "azuread_service_principal" "msgraph" {
  count     = length(var.graph_app_role_grants) > 0 ? 1 : 0
  client_id = data.azuread_application_published_app_ids.well_known[0].result["MicrosoftGraph"]
}

locals {
  # try() because Terraform evaluates both branches of a conditional, so a bare index would error
  # on grant-free calls where the data source has count 0.
  graph_app_role_ids = try(data.azuread_service_principal.msgraph[0].app_role_ids, {})
  graph_sp_object_id = try(data.azuread_service_principal.msgraph[0].object_id, null)

  # One instance per (grant, permission), keyed "<label>|<name-or-guid>". Keys are built purely
  # from configuration, so they stay plan-known; only the resolved role id is data-driven.
  graph_grant_instances = merge([
    for label, g in var.graph_app_role_grants : merge(
      { for n in g.role_names : "${label}|${n}" => {
        principal = g.principal_object_id
        role_id   = lookup(local.graph_app_role_ids, n, null)
        role_name = n
      } },
      { for i in g.role_ids : "${label}|${i}" => {
        principal = g.principal_object_id
        role_id   = i
        role_name = null
      } },
    )
  ]...)
}

resource "azuread_app_role_assignment" "graph" {
  for_each = local.graph_grant_instances

  app_role_id         = each.value.role_id
  principal_object_id = each.value.principal
  resource_object_id  = local.graph_sp_object_id

  lifecycle {
    precondition {
      condition     = each.value.role_id != null
      error_message = "Grant '${each.key}' names a permission that is not a Microsoft Graph APPLICATION permission (check the spelling against the Graph permissions reference; delegated scopes do not resolve here)."
    }
  }
}
