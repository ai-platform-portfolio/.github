variable "azure" {
  description = "Independent hosting resource group and Azure region."
  type = object({
    location            = string
    resource_group_name = string
  })
}

variable "environment" {
  description = "Container Apps environment name."
  type        = object({ name = string })
}

variable "application" {
  description = "Application name, hostname and warm replica intent."
  type = object({
    name         = string
    hostname     = string
    min_replicas = number
  })
}

variable "dns_zone" {
  type = object({
    name                = string
    resource_group_name = string
  })
  description = "Existing persistent public DNS zone; this root owns only the new host's records."
}

variable "registry" {
  type = object({
    name                = string
    resource_group_name = string
  })
  description = "Existing persistent ACR used by the shared Docker workflow."
}

variable "cluster" {
  type = object({
    resource_group_name = string
    name                = string
  })
  description = "AKS name to observe, including when it has been deleted."
}

variable "image" {
  type        = string
  description = "Published container image pinned by digest; supplied by the caller workflow."

  validation {
    condition     = can(regex("^[a-z0-9.-]+/[a-z0-9/._-]+@sha256:[a-f0-9]{64}$", var.image))
    error_message = "Supply a published registry/repository@sha256:digest image reference."
  }
}

variable "preview_cleanup" {
  description = "Nightly leftover cleanup schedule (UTC) and GitHub organization."
  type = object({
    schedule     = string
    github_owner = string
  })
}
