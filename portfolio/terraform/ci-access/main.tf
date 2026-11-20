data "azuread_service_principal" "microsoft_graph" {
  client_id = "00000003-0000-0000-c000-000000000000"
}

data "azurerm_client_config" "current" {}

data "azurerm_storage_account" "backend" {
  name                = var.backend_storage_account.name
  resource_group_name = var.backend_storage_account.resource_group_name
}

locals {
  scopes = {
    subscription = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
    backend      = data.azurerm_storage_account.backend.id
  }
}

# The existing publisher registration/federation is externally owned. This root
# owns the explicit Azure grants assigned to the publisher.
resource "azurerm_role_assignment" "ci_publisher" {
  for_each = var.ci_publisher.role_assignments

  scope = each.value.scope == "aks_namespace" ? format(
    "/subscriptions/%s/resourceGroups/%s/providers/Microsoft.ContainerService/managedClusters/%s/namespaces/%s",
    data.azurerm_client_config.current.subscription_id,
    each.value.aks_namespace.resource_group_name,
    each.value.aks_namespace.cluster_name,
    each.value.aks_namespace.namespace,
  ) : local.scopes[each.value.scope]

  role_definition_name = each.value.role_definition_name
  principal_id         = var.ci_publisher.principal_id
  principal_type       = "ServicePrincipal"
}

# Foundation plans need read-only user metadata and application configuration.
resource "azuread_app_role_assignment" "ci_read" {
  for_each = var.ci_publisher.graph_read_roles

  principal_object_id = var.ci_publisher.principal_id
  resource_object_id  = data.azuread_service_principal.microsoft_graph.object_id
  app_role_id         = data.azuread_service_principal.microsoft_graph.app_role_ids[each.value]
}

# Explicitly approved for automated workforce application changes. The assignment
# grant is tenant-wide; it must be bootstrapped by a directory administrator.
resource "azuread_app_role_assignment" "ci_write" {
  for_each = var.ci_publisher.graph_write_roles

  principal_object_id = var.ci_publisher.principal_id
  resource_object_id  = data.azuread_service_principal.microsoft_graph.object_id
  app_role_id         = data.azuread_service_principal.microsoft_graph.app_role_ids[each.value]
}
