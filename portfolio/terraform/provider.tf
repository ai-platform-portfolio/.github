terraform {
  required_version = ">= 1.17, < 2.0"

  backend "azurerm" {
    use_azuread_auth = true
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  # CI supplies OIDC through ARM_*; local runs can use any supported identity.
  resource_provider_registrations = "none"
}
