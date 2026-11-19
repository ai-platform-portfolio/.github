data "azurerm_client_config" "current" {}

data "azurerm_container_app_environment" "existing" {
  name                = var.host.environment
  resource_group_name = var.host.resource_group
}

data "azurerm_container_registry" "existing" {
  name                = var.registry.name
  resource_group_name = var.registry.resource_group
}

module "identity" {
  source              = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/managed-identity?ref=a35d3f702ae23a6c6d96f1623937fe177044e992"
  name                = var.preview_name
  resource_group_name = var.host.resource_group
  location            = data.azurerm_container_app_environment.existing.location

  role_assignments = {
    image_pull = {
      scope                = data.azurerm_container_registry.existing.id
      role_definition_name = "AcrPull"
    }

    # The observed cluster/resource group can be deleted and recreated. Reader
    # preserves that observation without granting preview code mutation access.
    cluster_status = {
      scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
      role_definition_name = "Reader"
    }
  }
}

module "application" {
  source                       = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/container-app?ref=a35d3f702ae23a6c6d96f1623937fe177044e992"
  name                         = var.preview_name
  resource_group_name          = var.host.resource_group
  container_app_environment_id = data.azurerm_container_app_environment.existing.id
  managed_identity_id          = module.identity.identity_id
  registry_server              = data.azurerm_container_registry.existing.login_server
  image                        = var.image
  external_ingress_enabled     = true

  environment_variables = {
    AZURE_CLIENT_ID       = module.identity.client_id
    AZURE_SUBSCRIPTION_ID = data.azurerm_client_config.current.subscription_id
    AKS_RESOURCE_GROUP    = var.cluster.resource_group
    AKS_NAME              = var.cluster.name
  }

  depends_on = [module.identity]
}

output "url" {
  description = "Azure-generated HTTPS preview URL."
  value       = module.application.url
}
