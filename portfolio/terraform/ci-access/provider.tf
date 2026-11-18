terraform {
  required_version = ">= 1.13.9, < 2.0"

  backend "azurerm" {
    use_azuread_auth = true
    key              = "ci-access.tfstate"
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

  resource_provider_registrations = "none"
}
