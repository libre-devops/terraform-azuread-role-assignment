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
