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
