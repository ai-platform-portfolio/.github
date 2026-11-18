data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "ci" {
  for_each = var.ci_roles

  name = each.value.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Condition = { StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        "token.actions.githubusercontent.com:sub" = "${var.github_subject_prefix}:environment:${each.value.environment}"
      } }
    }]
  })
}

# CI can read its bootstrap roles; modifying their trust requires the local
# administrator. Identity Center writes are restricted to this instance/region.
resource "aws_iam_role_policy" "ci_read" {
  for_each = var.ci_roles

  role = aws_iam_role.ci[each.key].name
  name = "foundation-read"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole"]
        Resource = [for role in var.ci_roles : "arn:aws:iam::${var.bootstrap_access.account_id}:role/${role.name}"]
      },
      {
        Effect   = "Allow"
        Action   = ["iam:GetOpenIDConnectProvider"]
        Resource = data.aws_iam_openid_connect_provider.github.arn
      },
      {
        Effect    = "Allow"
        Action    = ["sso:Describe*", "sso:Get*", "sso:List*"]
        Resource  = "*"
        Condition = { StringEquals = { "aws:RequestedRegion" = var.identity_center.region } }
      },
      {
        Effect = "Allow"
        Action = ["identitystore:DescribeUser", "identitystore:ListUsers", "identitystore:GetUserId"]
        Resource = [
          "arn:aws:identitystore::${var.bootstrap_access.account_id}:identitystore/${var.identity_center.identity_store_id}",
          "arn:aws:identitystore:::user/*"
        ]
        Condition = { StringEquals = { "aws:RequestedRegion" = var.identity_center.region } }
      }
      ], each.key == "apply" ? [
      {
        Effect = "Allow"
        Action = [
          "sso:CreatePermissionSet", "sso:UpdatePermissionSet", "sso:DeletePermissionSet",
          "sso:PutInlinePolicyToPermissionSet", "sso:DeleteInlinePolicyFromPermissionSet",
          "sso:CreateAccountAssignment", "sso:DeleteAccountAssignment", "sso:ProvisionPermissionSet",
          "sso:TagResource", "sso:UntagResource"
        ]
        Resource = [
          var.identity_center.instance_arn,
          "${replace(var.identity_center.instance_arn, ":instance/", ":permissionSet/")}/*",
          "arn:aws:sso:::account/${var.bootstrap_access.account_id}"
        ]
        Condition = { StringEquals = { "aws:RequestedRegion" = var.identity_center.region } }
      },
      {
        Effect = "Allow"
        Action = ["identitystore:CreateUser", "identitystore:UpdateUser", "identitystore:DeleteUser"]
        Resource = [
          "arn:aws:identitystore::${var.bootstrap_access.account_id}:identitystore/${var.identity_center.identity_store_id}",
          "arn:aws:identitystore:::user/*"
        ]
        Condition = { StringEquals = { "aws:RequestedRegion" = var.identity_center.region } }
      }
    ] : [])
  })
}
