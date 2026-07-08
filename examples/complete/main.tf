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
