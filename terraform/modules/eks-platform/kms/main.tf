# HIPAA §164.312(a)(2)(iv): encryption at rest for all PHI-adjacent data
# stores. Separate CMKs per data classification/service so a compromised
# key has blast-radius limited to one system, and key rotation is enabled.

resource "aws_kms_key" "eks_secrets" {
  description             = "CMK for EKS Kubernetes secrets envelope encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = { Purpose = "eks-secrets-encryption" }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EnableIAMPolicies"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action   = "kms:*"
      Resource = "*"
    }]
  })

}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.environment}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

resource "aws_kms_key" "rds" {
  description             = "CMK for RDS storage encryption (PHI datastore)"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = { Purpose = "rds-encryption" }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EnableIAMPolicies"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action   = "kms:*"
      Resource = "*"
    }]
  })

}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.environment}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_kms_key" "cloudtrail" {
  description             = "CMK for CloudTrail log encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = { Purpose = "cloudtrail-encryption" }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccountAccess"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = "kms:*"
        Resource  = "*"
        Condition = { StringEquals = { "kms:CallerAccount" = data.aws_caller_identity.current.account_id } }
      },
      {
        Sid       = "AllowCloudTrailEncrypt"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = ["kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = "*"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}
