terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = var.tags
}

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AllowGitHubOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      # StringEquals, not StringLike — no wildcards on the sub claim.
      # ADR-0003 documents this as StringEquals with an exact branch match;
      # an earlier version of this file used StringLike with an added
      # "repo:org/repo:environment:*" entry, which silently reopened the
      # branch restriction for any workflow targeting a GitHub Environment.
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}",
      ]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = var.deploy_role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600

  tags = var.tags
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid    = "TerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      var.state_bucket_arn,
      "${var.state_bucket_arn}/*",
    ]
  }

  statement {
    sid    = "TerraformStateLock"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
    ]
    resources = [var.state_lock_table_arn]
  }

  statement {
    sid    = "AssumeMemberAccountRoles"
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    resources = [
      "arn:aws:iam::*:role/${var.member_account_role_name}",
    ]
  }

  statement {
    sid    = "LandingZoneDeployInfra"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "ec2:Create*",
      "ec2:Delete*",
      "ec2:Modify*",
      "ec2:Attach*",
      "ec2:Detach*",
      "ec2:Authorize*",
      "ec2:Revoke*",
      "kms:CreateKey",
      "kms:DescribeKey",
      "kms:EnableKeyRotation",
      "kms:PutKeyPolicy",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:DisableKey",
      "kms:ScheduleKeyDeletion",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:UpdateAlias",
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:Describe*",
      "logs:PutRetentionPolicy",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
      "cloudtrail:CreateTrail",
      "cloudtrail:DeleteTrail",
      "cloudtrail:UpdateTrail",
      "cloudtrail:StartLogging",
      "cloudtrail:StopLogging",
      "cloudtrail:DescribeTrails",
      "cloudtrail:TagResource",
      "cloudtrail:UntagResource",
      "config:Describe*",
      "config:Put*",
      "config:Delete*",
      "config:Start*",
      "config:Stop*",
      "config:TagResource",
      "config:UntagResource",
      "guardduty:CreateDetector",
      "guardduty:DeleteDetector",
      "guardduty:UpdateDetector",
      "guardduty:CreateFilter",
      "guardduty:DeleteFilter",
      "guardduty:UpdateFilter",
      "guardduty:CreateIPSet",
      "guardduty:DeleteIPSet",
      "guardduty:Describe*",
      "guardduty:List*",
      "guardduty:TagResource",
      "guardduty:UntagResource",
      "securityhub:Enable*",
      "securityhub:Disable*",
      "securityhub:Describe*",
      "securityhub:List*",
      "securityhub:TagResource",
      "securityhub:UntagResource",
      "ram:CreateResourceShare",
      "ram:DeleteResourceShare",
      "ram:AssociateResourceShare",
      "ram:DisassociateResourceShare",
      "ram:UpdateResourceShare",
      "ram:Get*",
      "ram:List*",
      "ram:TagResource",
      "ram:UntagResource",
      "route53resolver:CreateFirewallRuleGroup",
      "route53resolver:DeleteFirewallRuleGroup",
      "route53resolver:AssociateFirewallRuleGroup",
      "route53resolver:DisassociateFirewallRuleGroup",
      "route53resolver:CreateResolverEndpoint",
      "route53resolver:DeleteResolverEndpoint",
      "route53resolver:CreateFirewallDomainList",
      "route53resolver:DeleteFirewallDomainList",
      "route53resolver:CreateFirewallRule",
      "route53resolver:DeleteFirewallRule",
      "route53resolver:UpdateFirewallRuleGroupAssociation",
      "route53resolver:Get*",
      "route53resolver:List*",
      "route53resolver:TagResource",
      "route53resolver:UntagResource",
      "access-analyzer:CreateAnalyzer",
      "access-analyzer:DeleteAnalyzer",
      "access-analyzer:UpdateAnalyzer",
      "access-analyzer:Get*",
      "access-analyzer:List*",
      "access-analyzer:TagResource",
      "access-analyzer:UntagResource",
      "detective:CreateGraph",
      "detective:DeleteGraph",
      "detective:Get*",
      "detective:List*",
      "detective:TagResource",
      "detective:UntagResource",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:GetBucketAcl",
      "s3:GetBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketVersioning",
      "s3:PutBucketEncryption",
      "s3:PutBucketPolicy",
      "s3:PutBucketAcl",
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketNotification",
      "s3:PutObjectLockConfiguration",
      "s3:PutBucketLogging",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:ec2:*:*:vpc/*",
      "arn:aws:ec2:*:*:subnet/*",
      "arn:aws:ec2:*:*:security-group/*",
      "arn:aws:ec2:*:*:route-table/*",
      "arn:aws:ec2:*:*:internet-gateway/*",
      "arn:aws:ec2:*:*:natgateway/*",
      "arn:aws:ec2:*:*:transit-gateway/*",
      "arn:aws:kms:*:*:key/*",
      "arn:aws:logs:*:*:log-group:*",
      "arn:aws:cloudtrail:*:*:trail/*",
      "arn:aws:config:*:*:config-rule/*",
      "arn:aws:config:*:*:configuration-recorder/*",
      "arn:aws:guardduty:*:*:detector/*",
      "arn:aws:securityhub:*:*:hub/default",
      "arn:aws:ram:*:*:resource-share/*",
      "arn:aws:route53resolver:*:*:firewall-rule-group/*",
      "arn:aws:route53resolver:*:*:firewall-domain-list/*",
      "arn:aws:route53resolver:*:*:resolver-endpoint/*",
      "arn:aws:access-analyzer:*:*:analyzer/*",
      "arn:aws:detective:*:*:graph/*",
      "arn:aws:s3:::*",
      "arn:aws:s3:::*/*",
    ]
  }

  statement {
    sid    = "LandingZoneDeployIAM"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:TagPolicy",
      "iam:UntagPolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UpdateAccountPasswordPolicy",
      "iam:GetAccountPasswordPolicy",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:PassRole",
    ]
    resources = [
      "arn:aws:iam::*:role/*",
      "arn:aws:iam::*:policy/*",
      "arn:aws:iam::*:instance-profile/*",
      "arn:aws:iam::*:oidc-provider/*",
      "arn:aws:iam::*:user/*",
      "arn:aws:iam::*:group/*",
    ]
  }

  statement {
    sid    = "LandingZoneDeployOrganizations"
    effect = "Allow"
    actions = [
      "organizations:CreateOrganization",
      "organizations:DescribeOrganization",
      "organizations:ListRoots",
      "organizations:CreateOrganizationalUnit",
      "organizations:DescribeOrganizationalUnit",
      "organizations:ListOrganizationalUnitsForParent",
      "organizations:CreatePolicy",
      "organizations:UpdatePolicy",
      "organizations:DeletePolicy",
      "organizations:DescribePolicy",
      "organizations:ListPolicies",
      "organizations:ListPoliciesForTarget",
      "organizations:AttachPolicy",
      "organizations:DetachPolicy",
      "organizations:EnableAWSServiceAccess",
      "organizations:EnablePolicyType",
      "organizations:EnableAllFeatures",
      "organizations:EnableOrganizationAdminAccount",
      "organizations:DescribeAccount",
      "organizations:ListAccounts",
      "organizations:TagResource",
      "organizations:ListTagsForResource",
    ]
    resources = [
      "arn:aws:organizations::*:organization/*",
      "arn:aws:organizations::*:ou/*",
      "arn:aws:organizations::*:policy/*",
      "arn:aws:organizations::*:account/*",
    ]
  }
}

resource "aws_iam_policy" "deploy" {
  name   = "${var.deploy_role_name}-policy"
  policy = data.aws_iam_policy_document.deploy.json
}

resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.deploy.name
  policy_arn = aws_iam_policy.deploy.arn
}
