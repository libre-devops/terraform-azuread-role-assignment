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
# Complete call: activate a built-in role, create a custom role, and assign both to a role-assignable
# security group. The role target is a group (not the identity running Terraform) on purpose: Azure
# forbids a principal from removing its OWN built-in directory role assignment, which would strand
# the stack on destroy. A group is a clean, reversible target. Every operation here needs
# RoleManagement.ReadWrite.Directory (the Privileged Role Administrator directory role), and the
# assignable group also needs it.
data "azuread_client_config" "current" {}

# The assignment target. Directory roles can only be assigned to a role-assignable security group.
resource "azuread_group" "target" {
  display_name       = "${var.short}-${terraform.workspace}-role-target"
  security_enabled   = true
  assignable_to_role = true
  owners             = [data.azuread_client_config.current.object_id]
}

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

  # Assign both roles to the target group: the built-in by directory_role_key, the custom by
  # custom_role_key.
  role_assignments = {
    group-directory-reader = {
      directory_role_key  = "dir-readers"
      principal_object_id = azuread_group.target.object_id
    }
    group-application-manager = {
      custom_role_key     = "app-manager"
      principal_object_id = azuread_group.target.object_id
    }
  }
}

# ------------------------------------------------------------------------------------------------
# The managed-identity shape: a user-assigned identity granted a Graph APPLICATION permission by
# name through graph_app_role_grants. This is the gap the rest of the family cannot reach (the
# identity has no app registration), and the exact pattern a Logic App or Function App identity
# needs. ServiceHealth.Read.All is deliberately benign. The azurerm resources below exist only to
# mint a real managed identity to grant to.
# ------------------------------------------------------------------------------------------------

locals {
  location  = lookup(var.regions, var.loc, "uksouth")
  rg_name   = "rg-${var.short}-${var.loc}-${terraform.workspace}-adra-cmp"
  uami_name = "id-${var.short}-${var.loc}-${terraform.workspace}-adra-cmp"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azuread-role-assignment" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "uami" {
  source  = "libre-devops/user-assigned-managed-identity/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  user_assigned_identities = {
    (local.uami_name) = {}
  }
}

module "graph_grants" {
  source = "../../"

  graph_app_role_grants = {
    "uami-service-health" = {
      principal_object_id = module.uami.principal_ids[local.uami_name]
      role_names          = ["ServiceHealth.Read.All"]
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | >= 3.0.0, < 4.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | >= 3.0.0, < 4.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_graph_grants"></a> [graph\_grants](#module\_graph\_grants) | ../../ | n/a |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_role_assignment"></a> [role\_assignment](#module\_role\_assignment) | ../../ | n/a |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |
| <a name="module_uami"></a> [uami](#module\_uami) | libre-devops/user-assigned-managed-identity/azurerm | ~> 4.0 |

## Resources

| Name | Type |
|------|------|
| [azuread_group.target](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/group) | resource |
| [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_activated_directory_role_template_ids"></a> [activated\_directory\_role\_template\_ids](#output\_activated\_directory\_role\_template\_ids) | Template ids of the activated built-in directory roles. |
| <a name="output_custom_directory_role_object_ids"></a> [custom\_directory\_role\_object\_ids](#output\_custom\_directory\_role\_object\_ids) | Object ids of the custom directory roles. |
| <a name="output_role_assignment_ids"></a> [role\_assignment\_ids](#output\_role\_assignment\_ids) | Ids of the directory role assignments. |
<!-- END_TF_DOCS -->
