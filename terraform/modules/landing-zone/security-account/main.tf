terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

check "applying_into_security_account" {
  assert {
    condition     = data.aws_caller_identity.current.account_id == var.security_account_id
    error_message = "Provider is authenticated to account ${data.aws_caller_identity.current.account_id}, but security_account_id is set to ${var.security_account_id}. Refusing to apply into the wrong account."
  }
}

resource "aws_guardduty_detector" "primary" {
  enable                       = true
  finding_publishing_frequency = var.guardduty_finding_frequency

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_guardduty_organization_configuration" "this" {
  auto_enable_organization_members = "ALL"
  detector_id                      = aws_guardduty_detector.primary.id

  datasources {
    s3_logs {
      auto_enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
  }

  # Delegation itself (aws_guardduty_organization_admin_account) lives in
  # the org-baseline module, because only the AWS Organizations management
  # account can call EnableOrganizationAdminAccount — this module runs
  # under the security account's own provider and would get AccessDenied
  # if it tried to register itself as delegated admin.
}

resource "aws_securityhub_account" "primary" {
  auto_enable_controls = true
}

# aws_securityhub_organization_admin_account has the same management-account
# requirement as GuardDuty above — see org-baseline module.

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.primary]
}

resource "aws_securityhub_standards_subscription" "afsbp" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.primary]
}

resource "aws_accessanalyzer_analyzer" "org" {
  analyzer_name = "org-analyzer"
  type          = "ORGANIZATION"
  tags          = var.tags
}

resource "aws_detective_graph" "primary" {
  tags = var.tags
}

resource "aws_detective_organization_configuration" "this" {
  auto_enable = true
  graph_arn   = aws_detective_graph.primary.graph_arn

  depends_on = [aws_detective_graph.primary]
}
