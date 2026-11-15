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
  source              = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/container-app-environment?ref=0c2b5bccd056a3021042430e54402e2f5a36eeb9"
  name                = var.environment.name
  resource_group_name = azurerm_resource_group.portfolio.name
  location            = var.azure.location
}

# AKS status is this application's intent, not a shared hosting-module default.
# Subscription scope preserves metadata visibility across disposable RG deletion.
resource "azurerm_role_definition" "cluster_status" {
  name              = "${var.application.name}-aks-status-reader"
  scope             = local.subscription_scope
  assignable_scopes = [local.subscription_scope]
  description       = "Read AKS resource metadata for the portfolio status page."

  permissions {
    actions = ["Microsoft.ContainerService/managedClusters/read"]
  }
}

module "identity" {
  source              = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/managed-identity?ref=0c2b5bccd056a3021042430e54402e2f5a36eeb9"
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
      role_definition_name = azurerm_role_definition.cluster_status.name
    }
  }
}

module "application" {
  source                       = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/container-app?ref=0c2b5bccd056a3021042430e54402e2f5a36eeb9"
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

  # Pull/runtime grants must exist before Azure starts the app.
  depends_on = [module.identity]
}
