variable "activated_directory_roles" {
  description = <<-DESC
    Built-in Entra (Azure AD) directory roles to activate in the tenant, keyed by a stable logical
    name. Built-in roles exist from templates but are dormant until activated; activating one
    exports its object id so assignments can be made against it. Reference an entry from
    role_assignments with directory_role_key. Provide exactly one of display_name or template_id
    per entry.
  DESC

  type = map(object({
    display_name = optional(string)
    template_id  = optional(string)
  }))

  default = {}

  validation {
    condition = alltrue([
      for k, v in var.activated_directory_roles :
      (v.display_name != null) != (v.template_id != null)
    ])
    error_message = "Each activated_directory_roles entry must set exactly one of display_name or template_id."
  }
}

variable "custom_directory_roles" {
  description = <<-DESC
    Custom Entra directory roles to create, keyed by a stable logical name. Each carries one or
    more permissions blocks listing allowed_resource_actions (see the Microsoft permissions
    reference). Reference an entry from role_assignments with custom_role_key.
  DESC

  type = map(object({
    display_name = string
    description  = optional(string)
    enabled      = optional(bool, true)
    version      = optional(string, "1.0")
    template_id  = optional(string)
    permissions = list(object({
      allowed_resource_actions = list(string)
    }))
  }))

  default = {}

  validation {
    condition = alltrue([
      for k, v in var.custom_directory_roles : length(v.permissions) > 0
    ])
    error_message = "Each custom_directory_roles entry must declare at least one permissions block."
  }

  validation {
    condition = alltrue([
      for k, v in var.custom_directory_roles : length(v.version) >= 1 && length(v.version) <= 128
    ])
    error_message = "custom_directory_roles version must be between 1 and 128 characters."
  }

  validation {
    condition = alltrue([
      for k, v in var.custom_directory_roles : alltrue([
        for p in v.permissions : length(p.allowed_resource_actions) > 0
      ])
    ])
    error_message = "Each permissions block must list at least one allowed_resource_action."
  }
}

variable "graph_app_role_grants" {
  description = <<DESC
Microsoft Graph APPLICATION permission grants (admin consent) to EXISTING principals, keyed by a
logical label you choose. This is the managed-identity shape the rest of the family cannot reach: a
Logic App, Function App, automation, or VM identity that needs app-only Graph has no app
registration of its own, so the service-principal module's in-call grants cannot target it, and
directory roles are the wrong tool. `role_names` take Graph permission names
(ServiceMessage.Read.All) and resolve against the tenant's Microsoft Graph service principal, so
configuration reads like the permission reference rather than GUID soup; `role_ids` take explicit
app role GUIDs for anything unusual. Each grant IS tenant-wide admin consent, and creating one needs
`AppRoleAssignment.ReadWrite.All` (or Global Administrator) on the applier.
DESC

  type = map(object({
    principal_object_id = string
    role_names          = optional(list(string), [])
    role_ids            = optional(list(string), [])
  }))
  default = {}

  validation {
    condition     = alltrue([for g in values(var.graph_app_role_grants) : length(g.role_names) + length(g.role_ids) > 0])
    error_message = "Every graph_app_role_grants entry must set at least one of role_names or role_ids."
  }

  validation {
    condition     = alltrue([for g in values(var.graph_app_role_grants) : can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", g.principal_object_id))])
    error_message = "Each principal_object_id must be an object id GUID: the service principal or managed identity OBJECT id, not an appId."
  }

  validation {
    condition     = alltrue([for g in values(var.graph_app_role_grants) : alltrue([for i in g.role_ids : can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", i))])])
    error_message = "Each role_ids entry must be an app role GUID."
  }
}

variable "privileged_graph_app_role_ids" {
  description = <<DESC
Graph application permissions treated as privileged by the warning check (name => app role GUID on
the Microsoft Graph service principal): each one is escalation-capable, able to grant or rewrite its
way to broader tenant control. Extend this to treat more permissions as privileged.
DESC

  type = map(string)
  default = {
    "Application.ReadWrite.All"          = "1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9"
    "AppRoleAssignment.ReadWrite.All"    = "06b708a9-e830-4db3-a914-8e69da51d44f"
    "Directory.ReadWrite.All"            = "19dbc75e-c2e2-444c-a770-ec69d8559fc7"
    "RoleManagement.ReadWrite.Directory" = "9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8"
  }

  validation {
    condition     = alltrue([for g in values(var.privileged_graph_app_role_ids) : can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", g))])
    error_message = "Each privileged_graph_app_role_ids value must be an app role GUID."
  }
}

variable "role_assignments" {
  description = <<-DESC
    Directory role assignments to create, keyed by a stable logical name. Each assigns one role to
    one principal (a user, group or service principal object id), optionally scoped to a single
    directory object (directory_scope_id) or an application-specific scope (app_scope_id).

    Reference the role in exactly one of three ways:
      - directory_role_key: a key from activated_directory_roles (assigns the built-in by template id)
      - custom_role_key:     a key from custom_directory_roles (assigns the custom role by object id)
      - role_id:             a raw template id (built-in) or object id (custom), for roles managed elsewhere
  DESC

  type = map(object({
    principal_object_id = string
    directory_role_key  = optional(string)
    custom_role_key     = optional(string)
    role_id             = optional(string)
    app_scope_id        = optional(string)
    directory_scope_id  = optional(string)
  }))

  default = {}

  validation {
    condition = alltrue([
      for k, v in var.role_assignments :
      length([for r in [v.directory_role_key, v.custom_role_key, v.role_id] : r if r != null]) == 1
    ])
    error_message = "Each role_assignments entry must reference the role in exactly one way: directory_role_key, custom_role_key or role_id."
  }

  validation {
    condition = alltrue([
      for k, v in var.role_assignments : !(v.app_scope_id != null && v.directory_scope_id != null)
    ])
    error_message = "app_scope_id and directory_scope_id are mutually exclusive on a role assignment."
  }
}
