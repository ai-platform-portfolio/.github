backend_storage_account = {
  name                = "localtfsa"
  resource_group_name = "claudeaiportfolio"
}

ci_publisher = {
  # Claims policy management is tenant-wide; Graph's known read issue needs both policy grants.
  graph_write_roles = ["Application.ReadWrite.OwnedBy", "AppRoleAssignment.ReadWrite.All", "Policy.ReadWrite.ApplicationConfiguration"]

  graph_read_roles = ["User.Read.All", "Application.Read.All", "Policy.Read.All"]

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

    management_aks = {
      scope                = "management_aks"
      role_definition_name = "Azure Kubernetes Service RBAC Writer"
    }
  }
}

management_aks = {
  resource_group_name = "rg-management"
  name                = "aks-management"
}
