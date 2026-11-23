variable "backend_storage_account" {
  description = "Existing persistent state account; this root creates no storage resources."
  type = object({
    name                = string
    resource_group_name = string
  })
}

variable "ci_publisher" {
  description = "Existing CI principal and its explicitly managed Azure role assignments."
  type = object({
    principal_id      = string
    graph_read_roles  = optional(set(string), [])
    graph_write_roles = optional(set(string), [])
    role_assignments = map(object({
      scope                = string
      role_definition_name = string
    }))
  })

  validation {
    condition     = alltrue([for assignment in var.ci_publisher.role_assignments : contains(["subscription", "backend"], assignment.scope)])
    error_message = "Select a declared subscription or backend scope."
  }
}

variable "telemetry_api_object_id" {
  description = "Entra application registration object ID for the existing private telemetry token audience."
  type        = string
}
