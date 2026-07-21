<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure AD Role Assignment

Manage Microsoft Entra (Azure AD) directory roles: activate built-in roles, define custom
directory roles, and assign either to users, groups or service principals, with optional scoping.
The companion to
[terraform-azuread-service-principal](https://github.com/libre-devops/terraform-azuread-service-principal)
for the directory-RBAC side of identity.

[![CI](https://github.com/libre-devops/terraform-azuread-role-assignment/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azuread-role-assignment/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azuread-role-assignment?sort=semver&label=release)](https://github.com/libre-devops/terraform-azuread-role-assignment/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azuread-role-assignment)](./LICENSE)

---

## Usage

```hcl
module "role_assignment" {
  source  = "libre-devops/role-assignment/azuread"
  version = "~> 4.0"

  activated_directory_roles = {
    reader = { display_name = "Directory Readers" }
  }

  role_assignments = {
    ci-reader = {
      directory_role_key  = "reader"
      principal_object_id = "00000000-0000-0000-0000-000000000000" # a user, group or SP object id
    }
  }
}
```

## Role references

A role assignment points at its role in exactly one of three ways:

- `directory_role_key` - a key from `activated_directory_roles` (assigns a built-in role by its template id)
- `custom_role_key` - a key from `custom_directory_roles` (assigns a custom role by its object id)
- `role_id` - a raw template id (built-in) or object id (custom), for roles managed elsewhere

## Graph application permission grants (the managed-identity shape)

`graph_app_role_grants` grants Microsoft Graph **application** permissions (admin consent) to
EXISTING principals, which is the shape managed identities need: a Logic App, Function App,
automation, or VM identity doing app-only Graph has no app registration of its own, so the
`service-principal` module's in-call grants cannot reach it and directory roles are the wrong tool.
Permissions are written as names and resolved against the tenant's Graph service principal:

```hcl
module "graph_grants" {
  source  = "libre-devops/role-assignment/azuread"
  version = "~> 4.2"

  graph_app_role_grants = {
    "logic-app-mi" = {
      principal_object_id = module.logic_app_workflow.identities["logic-ldo-uks-prd-001"].principal_id
      role_names          = ["ServiceMessage.Read.All", "Tasks.ReadWrite.All"]
    }
  }
}
```

A check block flags escalation-capable permissions (`Directory.ReadWrite.All`,
`RoleManagement.ReadWrite.Directory`, `Application.ReadWrite.All`, `AppRoleAssignment.ReadWrite.All`;
the set is caller-extendable) so a privileged grant is always a visible decision, never a quiet one.

## Required permissions

Managing directory roles (activation, custom roles and assignments) needs the running principal to
hold Microsoft Graph `RoleManagement.ReadWrite.Directory`, that is the **Privileged Role
Administrator** directory role. `graph_app_role_grants` additionally needs
`AppRoleAssignment.ReadWrite.All` (each grant IS tenant-wide admin consent). A check block flags any
attempt to touch Global Administrator so it is never assigned by accident.

## Examples

- [`examples/minimal`](./examples/minimal) - the smallest valid call: one custom directory role.
- [`examples/complete`](./examples/complete) - activate a built-in role, create a custom role, and assign both to a principal; plus a user-assigned managed identity granted a benign Graph application permission by name through `graph_app_role_grants`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | >= 3.0.0, < 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | >= 3.0.0, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_app_role_assignment.graph](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/app_role_assignment) | resource |
| [azuread_custom_directory_role.this](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/custom_directory_role) | resource |
| [azuread_directory_role.this](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/directory_role) | resource |
| [azuread_directory_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/directory_role_assignment) | resource |
| [azuread_application_published_app_ids.well_known](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/application_published_app_ids) | data source |
| [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) | data source |
| [azuread_service_principal.msgraph](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/service_principal) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_activated_directory_roles"></a> [activated\_directory\_roles](#input\_activated\_directory\_roles) | Built-in Entra (Azure AD) directory roles to activate in the tenant, keyed by a stable logical<br/>name. Built-in roles exist from templates but are dormant until activated; activating one<br/>exports its object id so assignments can be made against it. Reference an entry from<br/>role\_assignments with directory\_role\_key. Provide exactly one of display\_name or template\_id<br/>per entry. | <pre>map(object({<br/>    display_name = optional(string)<br/>    template_id  = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_custom_directory_roles"></a> [custom\_directory\_roles](#input\_custom\_directory\_roles) | Custom Entra directory roles to create, keyed by a stable logical name. Each carries one or<br/>more permissions blocks listing allowed\_resource\_actions (see the Microsoft permissions<br/>reference). Reference an entry from role\_assignments with custom\_role\_key. | <pre>map(object({<br/>    display_name = string<br/>    description  = optional(string)<br/>    enabled      = optional(bool, true)<br/>    version      = optional(string, "1.0")<br/>    template_id  = optional(string)<br/>    permissions = list(object({<br/>      allowed_resource_actions = list(string)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_graph_app_role_grants"></a> [graph\_app\_role\_grants](#input\_graph\_app\_role\_grants) | Microsoft Graph APPLICATION permission grants (admin consent) to EXISTING principals, keyed by a<br/>logical label you choose. This is the managed-identity shape the rest of the family cannot reach: a<br/>Logic App, Function App, automation, or VM identity that needs app-only Graph has no app<br/>registration of its own, so the service-principal module's in-call grants cannot target it, and<br/>directory roles are the wrong tool. `role_names` take Graph permission names<br/>(ServiceMessage.Read.All) and resolve against the tenant's Microsoft Graph service principal, so<br/>configuration reads like the permission reference rather than GUID soup; `role_ids` take explicit<br/>app role GUIDs for anything unusual. Each grant IS tenant-wide admin consent, and creating one needs<br/>`AppRoleAssignment.ReadWrite.All` (or Global Administrator) on the applier. | <pre>map(object({<br/>    principal_object_id = string<br/>    role_names          = optional(list(string), [])<br/>    role_ids            = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_privileged_graph_app_role_ids"></a> [privileged\_graph\_app\_role\_ids](#input\_privileged\_graph\_app\_role\_ids) | Graph application permissions treated as privileged by the warning check (name => app role GUID on<br/>the Microsoft Graph service principal): each one is escalation-capable, able to grant or rewrite its<br/>way to broader tenant control. Extend this to treat more permissions as privileged. | `map(string)` | <pre>{<br/>  "AppRoleAssignment.ReadWrite.All": "06b708a9-e830-4db3-a914-8e69da51d44f",<br/>  "Application.ReadWrite.All": "1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9",<br/>  "Directory.ReadWrite.All": "19dbc75e-c2e2-444c-a770-ec69d8559fc7",<br/>  "RoleManagement.ReadWrite.Directory": "9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8"<br/>}</pre> | no |
| <a name="input_role_assignments"></a> [role\_assignments](#input\_role\_assignments) | Directory role assignments to create, keyed by a stable logical name. Each assigns one role to<br/>one principal (a user, group or service principal object id), optionally scoped to a single<br/>directory object (directory\_scope\_id) or an application-specific scope (app\_scope\_id).<br/><br/>Reference the role in exactly one of three ways:<br/>  - directory\_role\_key: a key from activated\_directory\_roles (assigns the built-in by template id)<br/>  - custom\_role\_key:     a key from custom\_directory\_roles (assigns the custom role by object id)<br/>  - role\_id:             a raw template id (built-in) or object id (custom), for roles managed elsewhere | <pre>map(object({<br/>    principal_object_id = string<br/>    directory_role_key  = optional(string)<br/>    custom_role_key     = optional(string)<br/>    role_id             = optional(string)<br/>    app_scope_id        = optional(string)<br/>    directory_scope_id  = optional(string)<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_activated_directory_role_object_ids"></a> [activated\_directory\_role\_object\_ids](#output\_activated\_directory\_role\_object\_ids) | Map of activated built-in directory role key to its object id. |
| <a name="output_activated_directory_role_template_ids"></a> [activated\_directory\_role\_template\_ids](#output\_activated\_directory\_role\_template\_ids) | Map of activated built-in directory role key to its template id (the value used when assigning a built-in role). |
| <a name="output_custom_directory_role_object_ids"></a> [custom\_directory\_role\_object\_ids](#output\_custom\_directory\_role\_object\_ids) | Map of custom directory role key to its object id (the value used when assigning a custom role). |
| <a name="output_custom_directory_roles"></a> [custom\_directory\_roles](#output\_custom\_directory\_roles) | Map of custom directory role key to its useful attributes. |
| <a name="output_graph_app_role_grant_ids"></a> [graph\_app\_role\_grant\_ids](#output\_graph\_app\_role\_grant\_ids) | Map of grant instance key (label\|permission) to the app role assignment id. |
| <a name="output_role_assignment_ids"></a> [role\_assignment\_ids](#output\_role\_assignment\_ids) | Map of role assignment key to the directory role assignment id. |
<!-- END_TF_DOCS -->
