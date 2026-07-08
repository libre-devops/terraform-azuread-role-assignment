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

# The same, for a built-in role activated by display name.
check "flag_global_administrator_activation" {
  assert {
    condition = alltrue([
      for k, v in var.activated_directory_roles :
      lower(coalesce(v.display_name, "")) != "global administrator"
    ])
    error_message = "An activated_directory_roles entry activates Global Administrator. Confirm this is intended before assigning it to any principal."
  }
}
