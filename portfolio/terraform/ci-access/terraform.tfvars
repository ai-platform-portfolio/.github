backend_storage_account = {
  name                = "localtfsa"
  resource_group_name = "claudeaiportfolio"
}

ci_publisher = {
  principal_id = "34a1cc81-438a-4359-8d33-7a00a56e8d2a"

  role_assignments = {
    foundry = {
      scope                = "subscription"
      role_definition_name = "Foundry Project Manager"
    }

    backend = {
      scope                = "backend"
      role_definition_name = "Storage Blob Data Contributor"
    }
  }
}
