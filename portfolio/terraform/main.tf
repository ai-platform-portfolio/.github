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
  dns_label          = trimsuffix(var.hostname, ".${var.dns_zone.name}")
}

# Independent resource group and backend key: AKS teardown cannot remove the host.
resource "azurerm_resource_group" "portfolio" {
  name     = "rg-${var.name}-hosting"
  location = var.location
}

resource "azurerm_user_assigned_identity" "portfolio" {
  name                = "${var.name}-hosting"
  location            = azurerm_resource_group.portfolio.location
  resource_group_name = azurerm_resource_group.portfolio.name
}

resource "azurerm_role_assignment" "image_pull" {
  scope                = data.azurerm_container_registry.existing.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.portfolio.principal_id
}

# Resource-group/cluster-scoped assignments are deleted with disposable AKS.
# Only metadata GET is allowed, across this subscription, so delete/recreate
# remains observable without giving this identity kubeconfig or Kubernetes access.
resource "azurerm_role_definition" "cluster_status" {
  name              = "${var.name}-aks-status-reader"
  scope             = local.subscription_scope
  assignable_scopes = [local.subscription_scope]
  description       = "Read AKS resource metadata for the portfolio status page."

  permissions {
    actions = ["Microsoft.ContainerService/managedClusters/read"]
  }
}

resource "azurerm_role_assignment" "cluster_status" {
  scope              = local.subscription_scope
  role_definition_id = azurerm_role_definition.cluster_status.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.portfolio.principal_id
}

resource "azurerm_container_app_environment" "portfolio" {
  name                = "${var.name}-hosting"
  location            = azurerm_resource_group.portfolio.location
  resource_group_name = azurerm_resource_group.portfolio.name

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

resource "azurerm_container_app" "portfolio" {
  name                         = var.name
  resource_group_name          = azurerm_resource_group.portfolio.name
  container_app_environment_id = azurerm_container_app_environment.portfolio.id
  workload_profile_name        = "Consumption"
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.portfolio.id]
  }

  registry {
    server   = data.azurerm_container_registry.existing.login_server
    identity = azurerm_user_assigned_identity.portfolio.id
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = 8080
    transport                  = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "web"
      image  = var.image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.portfolio.client_id
      }

      env {
        name  = "AZURE_SUBSCRIPTION_ID"
        value = data.azurerm_client_config.current.subscription_id
      }

      env {
        name  = "AKS_RESOURCE_GROUP"
        value = var.cluster.resource_group_name
      }

      env {
        name  = "AKS_NAME"
        value = var.cluster.name
      }

      liveness_probe {
        transport        = "HTTP"
        port             = 8080
        path             = "/healthz"
        interval_seconds = 30
      }

      readiness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/healthz"
      }
    }
  }

  depends_on = [azurerm_role_assignment.image_pull]
}

resource "azurerm_dns_cname_record" "portfolio" {
  name                = local.dns_label
  zone_name           = data.azurerm_dns_zone.existing.name
  resource_group_name = data.azurerm_dns_zone.existing.resource_group_name
  ttl                 = 300
  record              = azurerm_container_app.portfolio.ingress[0].fqdn
}

resource "azurerm_dns_txt_record" "verification" {
  name                = "asuid.${local.dns_label}"
  zone_name           = data.azurerm_dns_zone.existing.name
  resource_group_name = data.azurerm_dns_zone.existing.resource_group_name
  ttl                 = 300

  record {
    value = azurerm_container_app.portfolio.custom_domain_verification_id
  }
}

resource "azurerm_container_app_custom_domain" "portfolio" {
  name             = var.hostname
  container_app_id = azurerm_container_app.portfolio.id

  # The AzAPI resource below owns only the managed-certificate binding.
  lifecycle {
    ignore_changes = [certificate_binding_type, container_app_environment_certificate_id]
  }

  depends_on = [azurerm_dns_cname_record.portfolio, azurerm_dns_txt_record.verification]
}

resource "azurerm_container_app_environment_managed_certificate" "portfolio" {
  name                         = "${var.name}-https"
  container_app_environment_id = azurerm_container_app_environment.portfolio.id
  subject_name                 = var.hostname
  domain_control_validation    = "CNAME"

  depends_on = [azurerm_container_app_custom_domain.portfolio]
}

# Remove the binding before deleting its certificate during host destruction.
# azapi_update_resource alone leaves its patched properties behind on destroy.
resource "azapi_resource_action" "unbind_https" {
  type                   = "Microsoft.App/containerApps@2025-07-01"
  resource_id            = azurerm_container_app.portfolio.id
  method                 = "PATCH"
  when                   = "destroy"
  response_export_values = []

  body = {
    properties = {
      configuration = {
        ingress = { customDomains = [] }
      }
    }
  }

  lifecycle {
    replace_triggered_by = [azurerm_container_app_environment_managed_certificate.portfolio]
  }

  depends_on = [azurerm_container_app_environment_managed_certificate.portfolio]
}

resource "azapi_update_resource" "https_binding" {
  type                   = "Microsoft.App/containerApps@2025-07-01"
  resource_id            = azurerm_container_app.portfolio.id
  response_export_values = []

  body = {
    properties = {
      configuration = {
        ingress = {
          customDomains = [{
            name          = var.hostname
            bindingType   = "SniEnabled"
            certificateId = azurerm_container_app_environment_managed_certificate.portfolio.id
          }]
        }
      }
    }
  }

  depends_on = [azapi_resource_action.unbind_https]
}
