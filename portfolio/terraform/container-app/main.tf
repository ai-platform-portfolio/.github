data "azurerm_client_config" "current" {}

data "azurerm_container_registry" "existing" {
  name                = var.registry.name
  resource_group_name = var.registry.resource_group_name
}

data "azurerm_dns_zone" "existing" {
  name                = var.dns_zone.name
  resource_group_name = var.dns_zone.resource_group_name
}

locals {
  subscription_scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

# The caller owns the independent root, resource group and deployment choices.
resource "azurerm_resource_group" "portfolio" {
  name     = var.azure.resource_group_name
  location = var.azure.location
}

module "environment" {
  source              = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/container-app-environment?ref=a35d3f702ae23a6c6d96f1623937fe177044e992"
  name                = var.environment.name
  resource_group_name = azurerm_resource_group.portfolio.name
  location            = var.azure.location
}

module "identity" {
  source              = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/managed-identity?ref=a35d3f702ae23a6c6d96f1623937fe177044e992"
  name                = var.environment.name
  resource_group_name = azurerm_resource_group.portfolio.name
  location            = var.azure.location

  role_assignments = {
    image_pull = {
      scope                = data.azurerm_container_registry.existing.id
      role_definition_name = "AcrPull"
    }

    cluster_status = {
      scope                = local.subscription_scope
      role_definition_name = "Contributor"
    }
  }
}

module "application" {
  source                       = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/container-app?ref=441f10efa69b2b67b6f5a6d19707493576ac5160"
  name                         = var.application.name
  resource_group_name          = azurerm_resource_group.portfolio.name
  container_app_environment_id = module.environment.id
  managed_identity_id          = module.identity.identity_id
  image                        = var.image
  registry_server              = data.azurerm_container_registry.existing.login_server
  replicas                     = { min = var.application.min_replicas }
  external_ingress_enabled     = true

  custom_domain = {
    hostname            = var.application.hostname
    zone_name           = data.azurerm_dns_zone.existing.name
    resource_group_name = data.azurerm_dns_zone.existing.resource_group_name
  }

  environment_variables = {
    AZURE_CLIENT_ID       = module.identity.client_id
    AZURE_SUBSCRIPTION_ID = data.azurerm_client_config.current.subscription_id
    AKS_RESOURCE_GROUP    = var.cluster.resource_group_name
    AKS_NAME              = var.cluster.name
  }

  scheduled_jobs = {
    preview-cleanup = {
      schedule = var.preview_cleanup.schedule
      command  = ["python"]
      args     = ["/app/preview_cleanup.py"]

      environment_variables = {
        AZURE_CLIENT_ID        = module.identity.client_id
        AZURE_SUBSCRIPTION_ID  = data.azurerm_client_config.current.subscription_id
        PREVIEW_RESOURCE_GROUP = azurerm_resource_group.portfolio.name
        PREVIEW_GITHUB_OWNER   = var.preview_cleanup.github_owner
      }
    }
  }

  # Pull/runtime grants must exist before Azure starts the app.
  depends_on = [module.identity]
}
