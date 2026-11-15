variable "location" {
  type        = string
  description = "Azure region for the independent portfolio host."
}

variable "name" {
  type        = string
  description = "Name for this hosting instance and its related resources."
  default     = "portfolio"
}

variable "hostname" {
  type        = string
  description = "New subdomain within the existing DNS zone."

  validation {
    condition     = endswith(var.hostname, ".${var.dns_zone.name}") && var.hostname != var.dns_zone.name
    error_message = "Use a subdomain of the configured DNS zone."
  }
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
