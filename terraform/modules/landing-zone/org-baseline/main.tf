terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

check "applying_into_management_account" {
  assert {
    condition     = data.aws_caller_identity.current.account_id == var.management_account_id
    error_message = "Provider is authenticated to account ${data.aws_caller_identity.current.account_id}, but management_account_id is set to ${var.management_account_id}. This module creates the AWS Organization and must run in the management account — refusing to apply into the wrong one."
  }
}

resource "aws_organizations_organization" "this" {
  feature_set = var.organization_feature_set

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "access-analyzer.amazonaws.com",
    "ram.amazonaws.com",
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]
}

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.this.roots[0].id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.this.roots[0].id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.this.roots[0].id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.this.roots[0].id
  tags      = var.tags
}

# SCP: Deny leaving the organization
data "aws_iam_policy_document" "deny_leave_org" {
  statement {
    sid       = "DenyLeaveOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }
}

resource "aws_organizations_policy" "deny_leave_org" {
  name        = "deny-leave-organization"
  description = "Prevents member accounts from leaving the organization."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.deny_leave_org.json
  tags        = var.tags
}

# SCP: Deny root user actions
data "aws_iam_policy_document" "deny_root_user" {
  statement {
    sid    = "DenyRootUserActions"
    effect = "Deny"
    not_actions = [
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:GetAccountSummary",
      "iam:ListMFADevices",
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::*:root"]
    }
  }
}

resource "aws_organizations_policy" "deny_root_user" {
  name        = "deny-root-user"
  description = "Denies root user actions in member accounts (except MFA setup)."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.deny_root_user.json
  tags        = var.tags
}

# SCP: Deny unencrypted S3 uploads
data "aws_iam_policy_document" "deny_unencrypted_s3" {
  statement {
    sid       = "DenyUnencryptedObjectUploads"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms", "AES256"]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_organizations_policy" "deny_unencrypted_s3" {
  name        = "deny-unencrypted-s3"
  description = "Requires TLS and encryption on S3 uploads."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.deny_unencrypted_s3.json
  tags        = var.tags
}

# Attach SCPs
resource "aws_organizations_policy_attachment" "deny_leave_workloads" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "deny_root_workloads" {
  policy_id = aws_organizations_policy.deny_root_user.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "deny_unencrypted_s3_workloads" {
  policy_id = aws_organizations_policy.deny_unencrypted_s3.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# Delegated admin registration — must run in the management account,
# which is why this lives here rather than in the security-account module.
# The security-account module then enables the actual services (GuardDuty
# detector, Security Hub) under the security account's own provider.
resource "aws_guardduty_organization_admin_account" "this" {
  admin_account_id = var.security_account_id
}

resource "aws_securityhub_organization_admin_account" "this" {
  admin_account_id = var.security_account_id
}

# Account password policy for the management account
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 24
  hard_expiry                    = false
}
