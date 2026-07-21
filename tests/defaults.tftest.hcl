# Plan-time tests for the module. The azuread provider is mocked, so no credentials and no cloud
# calls are needed:
#   terraform init -backend=false && terraform test

# The Graph data sources are mocked with fixed maps so graph_app_role_grants name resolution works
# the same way it would against a real tenant.
mock_provider "azuread" {
  mock_data "azuread_application_published_app_ids" {
    defaults = {
      result = { MicrosoftGraph = "00000003-0000-0000-c000-000000000000" }
    }
  }

  mock_data "azuread_service_principal" {
    defaults = {
      object_id = "0a0a0a0a-0b0b-0c0c-0d0d-0e0e0e0e0e0e"
      app_role_ids = {
        "ServiceMessage.Read.All"            = "1b620472-6534-4fe6-9df2-4680e8aa28ec"
        "Tasks.ReadWrite.All"                = "44e666d1-d276-445b-a5fc-8815eeb81d55"
        "RoleManagement.ReadWrite.Directory" = "9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8"
      }
    }
  }
}

variables {
  activated_directory_roles = {
    dir-readers = { display_name = "Directory Readers" }
    # By template id (User Administrator): display_name stays null, which the Global Administrator
    # activation check must tolerate (caught live by the group module's complete example).
    user-admin = { template_id = "fe930be7-5e62-47db-91af-98c3a49a38b1" }
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
    condition     = length(azuread_directory_role.this) == 2
    error_message = "A built-in directory role should be activated per entry, whether referenced by display name or template id."
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

run "grants_graph_app_roles_by_name" {
  command = plan

  variables {
    graph_app_role_grants = {
      "logic-app-mi" = {
        principal_object_id = "11111111-1111-1111-1111-111111111111"
        role_names          = ["ServiceMessage.Read.All", "Tasks.ReadWrite.All"]
      }
    }
  }

  assert {
    condition     = length(azuread_app_role_assignment.graph) == 2
    error_message = "Each named permission should become one app role assignment."
  }

  assert {
    condition     = azuread_app_role_assignment.graph["logic-app-mi|ServiceMessage.Read.All"].app_role_id == "1b620472-6534-4fe6-9df2-4680e8aa28ec"
    error_message = "role_names should resolve to app role GUIDs via the Graph service principal."
  }

  assert {
    condition     = azuread_app_role_assignment.graph["logic-app-mi|ServiceMessage.Read.All"].resource_object_id == "0a0a0a0a-0b0b-0c0c-0d0d-0e0e0e0e0e0e"
    error_message = "Grants should target the tenant Graph service principal's object id."
  }
}

run "grants_graph_app_roles_by_id" {
  command = plan

  variables {
    graph_app_role_grants = {
      "uami" = {
        principal_object_id = "22222222-2222-2222-2222-222222222222"
        role_ids            = ["79c261e0-fe76-4144-aad5-bdc68fbe4037"]
      }
    }
  }

  assert {
    condition     = azuread_app_role_assignment.graph["uami|79c261e0-fe76-4144-aad5-bdc68fbe4037"].app_role_id == "79c261e0-fe76-4144-aad5-bdc68fbe4037"
    error_message = "role_ids should pass through as-is."
  }
}

run "rejects_grant_without_roles" {
  command = plan

  variables {
    graph_app_role_grants = {
      "empty" = {
        principal_object_id = "11111111-1111-1111-1111-111111111111"
      }
    }
  }

  expect_failures = [var.graph_app_role_grants]
}

run "rejects_grant_with_bad_principal" {
  command = plan

  variables {
    graph_app_role_grants = {
      "bad" = {
        principal_object_id = "not-a-guid"
        role_names          = ["ServiceMessage.Read.All"]
      }
    }
  }

  expect_failures = [var.graph_app_role_grants]
}

run "rejects_unknown_permission_name" {
  command = plan

  variables {
    graph_app_role_grants = {
      "typo" = {
        principal_object_id = "11111111-1111-1111-1111-111111111111"
        role_names          = ["ServiceMessage.Reads.All"]
      }
    }
  }

  expect_failures = [azuread_app_role_assignment.graph]
}

run "warns_on_privileged_graph_grant" {
  command = plan

  variables {
    graph_app_role_grants = {
      "scary" = {
        principal_object_id = "11111111-1111-1111-1111-111111111111"
        role_names          = ["RoleManagement.ReadWrite.Directory"]
      }
    }
  }

  expect_failures = [check.flag_privileged_graph_app_role_grants]
}
