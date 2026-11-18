variable "identity_center" {
  description = "Existing account-access Identity Center instance and its SAML service-provider metadata."
  type = object({
    region            = string
    instance_arn      = string
    identity_store_id = string
    portal_url        = string
    entity_id         = string
    acs_url           = string
  })
}

variable "operators" {
  description = "Entra UPNs to assign and provision once, keyed by stable operator names. Terraform is their Identity Store owner; do not also enable SCIM for them."
  type        = map(string)

  validation {
    condition     = length(var.operators) > 0 && length(distinct([for upn in var.operators : lower(upn)])) == length(var.operators)
    error_message = "Declare at least one operator, with no duplicate UPNs."
  }
}

variable "application" {
  description = "Entra gallery application and role used for operator SAML access."
  type = object({
    name          = string
    template_name = string
    role_name     = string
  })
}

variable "bootstrap_access" {
  description = "Native CLI profile, permission-set name and the GitOps-owned gateway IAM role it may administer."
  type = object({
    account_id      = string
    profile_name    = string
    permission_set  = string
    gateway_role    = string
    workload_region = string
  })

  validation {
    condition     = can(regex("^[0-9]{12}$", var.bootstrap_access.account_id)) && can(regex("^[A-Za-z0-9_-]+$", var.bootstrap_access.profile_name)) && can(regex("^[A-Za-z0-9_+=,.@-]+$", var.bootstrap_access.gateway_role))
    error_message = "Declare a 12-digit target account, a plain profile name and one exact IAM role name without wildcard or path."
  }
}
