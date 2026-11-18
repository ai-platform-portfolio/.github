output "enterprise_application_object_id" {
  description = "Enterprise application to use for the one-time SAML metadata exchange."
  value       = module.entra.principal_id
}

output "signing_certificate_thumbprint" {
  description = "Verify/activate this public SAML signing thumbprint in Entra before exporting metadata."
  value       = module.entra.signing_certificate_thumbprint
}

output "aws_config" {
  description = "Native refreshable profile to merge into ~/.aws/config; contains no credential values."
  value = templatefile("${path.module}/aws-config.tftpl", {
    profile_name = var.bootstrap_access.profile_name
    start_url    = var.identity_center.portal_url
    sso_region   = var.identity_center.region
    region       = var.bootstrap_access.workload_region
    account_id   = var.bootstrap_access.account_id
    role_name    = module.aws_access.role_name
  })
}
