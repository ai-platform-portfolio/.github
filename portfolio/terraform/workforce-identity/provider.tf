terraform {
  required_version = ">= 1.13.9, < 2.0"

  backend "azurerm" {
    use_azuread_auth = true
    key              = "workforce-identity.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

# The foundation is administered using an existing authorised identity. Its new
# bootstrap permission set cannot administer Identity Center or grant itself access.
provider "aws" {
  region = var.identity_center.region
}

provider "azuread" {}
