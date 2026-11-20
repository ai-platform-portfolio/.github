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
      aks_namespace = optional(object({
        resource_group_name = string
        cluster_name        = string
        namespace           = string
      }))
    }))
  })

  validation {
    condition = alltrue([
      for assignment in var.ci_publisher.role_assignments :
      contains(["subscription", "backend", "aks_namespace"], assignment.scope) &&
      ((assignment.scope == "aks_namespace") == (assignment.aks_namespace != null))
    ])
    error_message = "Select subscription, backend, or aks_namespace and provide namespace details only for aks_namespace."
  }
}
