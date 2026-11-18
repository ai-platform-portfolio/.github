data "azuread_user" "operators" {
  for_each = var.operators

  user_principal_name = each.value
}

data "aws_iam_policy_document" "bootstrap" {
  statement {
    sid = "GatewayRoleLifecycle"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole",
      "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
      "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
    ]
    resources = ["arn:aws:iam::${var.bootstrap_access.account_id}:role/${var.bootstrap_access.gateway_role}"]
  }

  statement {
    sid = "AksIssuerLifecycle"
    actions = [
      "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:AddClientIDToOpenIDConnectProvider", "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider", "iam:ListOpenIDConnectProviderTags",
    ]
    # Recreated AKS clusters have new issuer paths. Restrict them to Azure AKS's
    # issuer hostname family in this account, without depending on a live cluster.
    resources = ["arn:aws:iam::${var.bootstrap_access.account_id}:oidc-provider/*.oic.prod-aks.azure.com/*"]
  }
}

module "entra" {
  source = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/saml-application?ref=d3288880d29671f5e4fe58dd61e1ec0a74d36bf2"

  display_name  = var.application.name
  template_name = var.application.template_name
  owners        = concat([for operator in data.azuread_user.operators : operator.object_id], tolist(var.application.additional_owners))
  service_provider = {
    entity_id = var.identity_center.entity_id
    acs_url   = var.identity_center.acs_url
    start_url = var.identity_center.portal_url
  }
  assignments = { for name, operator in data.azuread_user.operators : name => {
    principal_object_id = operator.object_id
    role_name           = var.application.role_name
  } }
}

resource "aws_identitystore_user" "operators" {
  for_each = data.azuread_user.operators

  identity_store_id = var.identity_center.identity_store_id
  user_name         = each.value.user_principal_name
  display_name      = each.value.display_name

  name {
    given_name  = each.value.given_name
    family_name = each.value.surname
  }

  emails {
    value   = coalesce(each.value.mail, each.value.user_principal_name)
    primary = true
  }
}

module "aws_access" {
  source = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/aws/identity-center-access?ref=25831afa415fafda7af551b69acba4eaa182ff43"

  instance_arn     = var.identity_center.instance_arn
  account_id       = var.bootstrap_access.account_id
  name             = var.bootstrap_access.permission_set
  description      = "Manage only the portfolio gateway role and AKS OIDC providers"
  session_duration = "PT1H"
  policy           = data.aws_iam_policy_document.bootstrap.json
  principals = { for name, operator in aws_identitystore_user.operators : name => {
    id   = operator.user_id
    type = "USER"
  } }
}
