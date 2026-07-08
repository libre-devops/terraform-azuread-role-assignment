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
