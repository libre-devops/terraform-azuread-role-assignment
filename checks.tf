# check blocks run after every plan and apply and emit a warning (without blocking) when an
# invariant is violated.

# Global Administrator is the highest-privilege directory role. Assigning it by raw template id is
# almost never what an infrastructure module should do silently, so surface it for review. The
# template id is well-known and stable.
check "flag_global_administrator_assignment" {
  assert {
    condition = alltrue([
      for k, v in var.role_assignments :
      v.role_id != "62e90394-69f5-4237-9190-012177145e10"
    ])
    error_message = "A role assignment targets the Global Administrator template id (62e90394-69f5-4237-9190-012177145e10). Confirm this is intended: it grants the highest privilege in the tenant."
  }
}

# The same, for a built-in role activated by display name or template id. Each side is guarded
# with its own conditional because exactly one of the two is set (coalesce cannot express this:
# it rejects a null-and-empty-string argument list outright).
check "flag_global_administrator_activation" {
  assert {
    condition = alltrue([
      for k, v in var.activated_directory_roles :
      (v.display_name == null ? true : lower(v.display_name) != "global administrator") &&
      (v.template_id == null ? true : v.template_id != "62e90394-69f5-4237-9190-012177145e10")
    ])
    error_message = "An activated_directory_roles entry activates Global Administrator. Confirm this is intended before assigning it to any principal."
  }
}

# Azure forbids a principal from removing its own built-in directory role assignment, so a built-in
# role assigned to the identity running Terraform (self) cannot be destroyed and will strand the
# stack. Assign built-in roles to a group or another principal instead.
check "no_self_builtin_role_assignment" {
  assert {
    condition = alltrue([
      for k, v in var.role_assignments :
      !(v.directory_role_key != null && v.principal_object_id == data.azuread_client_config.current.object_id)
    ])
    error_message = "A role assignment grants a built-in directory role to the principal running Terraform (self). Azure will not allow removing self from a built-in role, so destroy will fail. Assign built-in roles to a group or another principal."
  }
}

# Granting an escalation-capable Graph application permission (each of these can grant or rewrite
# its way to tenant control) is sometimes exactly the job, but should never happen invisibly.
check "flag_privileged_graph_app_role_grants" {
  assert {
    condition = alltrue([
      for k, inst in local.graph_grant_instances :
      !(contains(keys(var.privileged_graph_app_role_ids), coalesce(inst.role_name, "-")) || contains(values(var.privileged_graph_app_role_ids), coalesce(inst.role_id, "-")))
    ])
    error_message = "These grants carry privileged (escalation-capable) Graph application permissions: ${join(", ", [for k, inst in local.graph_grant_instances : k if contains(keys(var.privileged_graph_app_role_ids), coalesce(inst.role_name, "-")) || contains(values(var.privileged_graph_app_role_ids), coalesce(inst.role_id, "-"))])}. Deliberate grants are fine; this check exists so they are always visible."
  }
}
