<!--
  Header for the complete example README. Edit this file, then run `just docs`
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

# Complete example

Activates the read-only **Directory Readers** built-in role, creates a custom **application
manager** role, and assigns both to the identity running Terraform (self, which keeps the example
self-contained and reversible). Every operation needs `RoleManagement.ReadWrite.Directory` (the
Privileged Role Administrator directory role). Run it with `just e2e complete`, which applies the
stack then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
# Complete call: activate a built-in role, create a custom role, and assign both to a principal.
# The principal here is the identity running Terraform (self), which keeps the example free of any
# other object to create. Directory Readers is read only, so the self assignment is benign and is
# removed on destroy. Every operation here needs RoleManagement.ReadWrite.Directory (the Privileged
# Role Administrator directory role) on the running principal.
data "azuread_client_config" "current" {}

module "role_assignment" {
  source = "../../"

  # Activate a benign, read-only built-in role so it can be assigned.
  activated_directory_roles = {
    dir-readers = {
      display_name = "Directory Readers"
    }
  }

  # A custom role with a couple of application-management actions, spread over two permissions
  # blocks to show the block list.
  custom_directory_roles = {
    app-manager = {
      display_name = "${var.short}-${terraform.workspace}-application-manager"
      description  = "Read applications and update their basic properties and credentials."
      version      = "1.0"
      permissions = [
        {
          allowed_resource_actions = [
            "microsoft.directory/applications/standard/read",
            "microsoft.directory/applications/basic/update",
          ]
        },
        {
          allowed_resource_actions = [
            "microsoft.directory/applications/credentials/update",
          ]
        },
      ]
    }
  }

  # Assign both roles to the running principal: the built-in by directory_role_key, the custom by
  # custom_role_key.
  role_assignments = {
    self-directory-reader = {
      directory_role_key  = "dir-readers"
      principal_object_id = data.azuread_client_config.current.object_id
    }
    self-application-manager = {
      custom_role_key     = "app-manager"
      principal_object_id = data.azuread_client_config.current.object_id
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

| Name | Version |
|------|---------|
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | >= 3.0.0, < 4.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_role_assignment"></a> [role\_assignment](#module\_role\_assignment) | ../../ | n/a |

## Resources

| Name | Type |
|------|------|
| [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_activated_directory_role_template_ids"></a> [activated\_directory\_role\_template\_ids](#output\_activated\_directory\_role\_template\_ids) | Template ids of the activated built-in directory roles. |
| <a name="output_custom_directory_role_object_ids"></a> [custom\_directory\_role\_object\_ids](#output\_custom\_directory\_role\_object\_ids) | Object ids of the custom directory roles. |
| <a name="output_role_assignment_ids"></a> [role\_assignment\_ids](#output\_role\_assignment\_ids) | Ids of the directory role assignments. |
<!-- END_TF_DOCS -->
