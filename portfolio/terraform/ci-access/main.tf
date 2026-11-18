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
# owns only the explicit grants formerly managed by disposable GitOps bootstrap.
resource "azurerm_role_assignment" "ci_publisher" {
  for_each = var.ci_publisher.role_assignments

  scope                = local.scopes[each.value.scope]
  role_definition_name = each.value.role_definition_name
  principal_id         = var.ci_publisher.principal_id
  principal_type       = "ServicePrincipal"
}
