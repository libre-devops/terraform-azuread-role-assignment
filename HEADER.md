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