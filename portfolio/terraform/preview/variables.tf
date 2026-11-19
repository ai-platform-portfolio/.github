variable "preview_name" {
  description = "Stable repository/PR identity supplied by the shared preview workflow."
  type        = string

  validation {
    condition     = can(regex("^pv-[a-f0-9]{12}-pr-[1-9][0-9]{0,9}$", var.preview_name))
    error_message = "Use the generated repository/PR preview identity."
  }
}

variable "image" {
  description = "Scanned image supplied by digest; unused during destroy."
  type        = string
}

variable "host" {
  description = "Existing persistent Container Apps environment."
  type = object({
    environment    = string
    resource_group = string
  })
}

variable "registry" {
  description = "Existing registry; previews own no registry resources."
  type = object({
    name           = string
    resource_group = string
  })
}

variable "cluster" {
  description = "Cluster whose status the portfolio observes."
  type = object({
    name           = string
    resource_group = string
  })
}
