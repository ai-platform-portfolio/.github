# Actual London Identity Center metadata; runtime Bedrock region remains Paris.
identity_center = {
  region            = "eu-west-2"
  instance_arn      = "arn:aws:sso:::instance/ssoins-7535396ffca41c3c"
  identity_store_id = "d-9c67b68e32"
  portal_url        = "https://ssoins-7535396ffca41c3c.portal.eu-west-2.app.aws"
  entity_id         = "https://eu-west-2.signin.aws.amazon.com/platform/saml/d-9c67b68e32"
  acs_url           = "https://eu-west-2.signin.aws/platform/saml/acs/4c48522d8e4c17ed-ae87-4991-ac1a-7862445eab24"
}

operators = {
  owner = "michaelalinks_outlook.com#EXT#@michaelalinksoutlook.onmicrosoft.com"
}

application = {
  additional_owners = ["34a1cc81-438a-4359-8d33-7a00a56e8d2a"]

  name           = "portfolio-aws-identity-center"
  template_name  = "AWS IAM Identity Center (successor to AWS Single Sign-On)"
  role_name      = "User"
  name_id_source = "localuserprincipalname"
}

bootstrap_access = {
  account_id      = "288039021924"
  profile_name    = "model-gateway"
  permission_set  = "PortfolioGatewayBootstrap"
  gateway_role    = "management-litellm-bedrock"
  workload_region = "eu-west-3"
}

github_subject_prefix = "repo:ai-platform-portfolio@334196300/.github@1390504897"

ci_roles = {
  plan = {
    name        = "portfolio-workforce-plan"
    environment = "central-plan"
  }

  apply = {
    name        = "portfolio-workforce-apply"
    environment = "central-apply"
  }
}
