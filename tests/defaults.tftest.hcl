# Plan-time tests for the module. The azuread provider is mocked, so no credentials and no cloud
# calls are needed:
#   terraform init -backend=false && terraform test

mock_provider "azuread" {}

variables {
  activated_directory_roles = {
    dir-readers = { display_name = "Directory Readers" }
  }

  custom_directory_roles = {
    app-mgr = {
      display_name = "example-application-manager"
      permissions = [
        { allowed_resource_actions = ["microsoft.directory/applications/standard/read"] }
      ]
    }
  }

  role_assignments = {
    a-custom = {
      custom_role_key     = "app-mgr"
      principal_object_id = "11111111-1111-1111-1111-111111111111"
    }
    a-builtin = {
      directory_role_key  = "dir-readers"
      principal_object_id = "22222222-2222-2222-2222-222222222222"
    }
    a-raw = {
      role_id             = "aaaaaaaa-1111-2222-3333-444444444444"
      principal_object_id = "33333333-3333-3333-3333-333333333333"
    }
  }
}

run "roles_are_created" {
  command = plan

  assert {
    condition     = length(azuread_custom_directory_role.this) == 1
    error_message = "One custom directory role should be created."
  }

  assert {
    condition     = length(azuread_directory_role.this) == 1
    error_message = "One built-in directory role should be activated."
  }
}

run "assignments_are_created_for_each_entry" {
  command = plan

  assert {
    condition     = length(azuread_directory_role_assignment.this) == 3
    error_message = "One assignment should be created per role_assignments entry."
  }
}

run "raw_role_id_is_passed_through" {
  command = plan

  assert {
    condition     = azuread_directory_role_assignment.this["a-raw"].role_id == "aaaaaaaa-1111-2222-3333-444444444444"
    error_message = "A raw role_id should be used verbatim on the assignment."
  }

  assert {
    condition     = azuread_directory_role_assignment.this["a-custom"].principal_object_id == "11111111-1111-1111-1111-111111111111"
    error_message = "The principal object id should be carried onto the assignment."
  }
}

run "role_reference_must_be_exactly_one" {
  command = plan

  variables {
    role_assignments = {
      bad = {
        custom_role_key     = "app-mgr"
        role_id             = "aaaaaaaa-1111-2222-3333-444444444444"
        principal_object_id = "11111111-1111-1111-1111-111111111111"
      }
    }
  }

  expect_failures = [var.role_assignments]
}

run "scopes_are_mutually_exclusive" {
  command = plan

  variables {
    role_assignments = {
      bad = {
        role_id             = "aaaaaaaa-1111-2222-3333-444444444444"
        principal_object_id = "11111111-1111-1111-1111-111111111111"
        app_scope_id        = "/"
        directory_scope_id  = "/administrativeUnits/x"
      }
    }
  }

  expect_failures = [var.role_assignments]
}

run "activated_role_needs_exactly_one_identifier" {
  command = plan

  variables {
    activated_directory_roles = {
      bad = { display_name = "Directory Readers", template_id = "88888888-8888-8888-8888-888888888888" }
    }
  }

  expect_failures = [var.activated_directory_roles]
}
