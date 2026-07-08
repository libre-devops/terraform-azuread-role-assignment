<!--
  Header for the minimal example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Minimal example

The smallest valid call: a single custom directory role. Needs the running principal to hold
`RoleManagement.ReadWrite.Directory` (the Privileged Role Administrator directory role). Run it
with `just e2e minimal`, which applies the stack then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
# Minimal call: create a single custom directory role. This is the smallest useful shape. Managing
# directory roles (custom roles, activation, assignment) needs the running principal to hold
# RoleManagement.ReadWrite.Directory (the Privileged Role Administrator directory role).
module "role_assignment" {
  source = "../../"

  custom_directory_roles = {
    app-reader = {
      display_name = "${var.short}-${terraform.workspace}-application-reader"
      description  = "Read application registrations."
      permissions = [
        {
          allowed_resource_actions = ["microsoft.directory/applications/standard/read"]
        }
      ]
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | >= 3.0.0, < 4.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_role_assignment"></a> [role\_assignment](#module\_role\_assignment) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_custom_directory_role_object_ids"></a> [custom\_directory\_role\_object\_ids](#output\_custom\_directory\_role\_object\_ids) | Object ids of the custom directory roles, keyed by role name. |
<!-- END_TF_DOCS -->
