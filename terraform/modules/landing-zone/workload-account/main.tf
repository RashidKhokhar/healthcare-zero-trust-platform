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

check "applying_into_workload_account" {
  assert {
    condition     = data.aws_caller_identity.current.account_id == var.workload_account_id
    error_message = "Provider is authenticated to account ${data.aws_caller_identity.current.account_id}, but workload_account_id is set to ${var.workload_account_id}. Refusing to apply into the wrong account."
  }
}

resource "aws_kms_key" "workload" {
  description             = "Workload CMK for ${var.workload_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.workload_name}-cmk"
  })

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EnableAccountIAMPolicies"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action   = "kms:*"
      Resource = "*"
    }]
  })

}

resource "aws_kms_alias" "workload" {
  name          = "alias/${var.workload_name}"
  target_key_id = aws_kms_key.workload.key_id
}

resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "boundary" {
  statement {
    sid    = "AllowSSMManagedInstanceCore"
    effect = "Allow"

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowInstanceInformationUpdates"
    effect = "Allow"

    actions = ["ssm:UpdateInstanceInformation"]

    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*",
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:managed-instance/*"
    ]
  }

  statement {
    sid    = "DenyIdentityAndOrgActions"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:PutUserPolicy",
      "iam:AttachUserPolicy",
      "organizations:*",
      "account:*",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DenyUnencryptedS3Uploads"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms", "AES256"]
    }
  }
}

resource "aws_iam_policy" "workload_boundary" {
  name        = "${var.workload_name}-boundary"
  description = "Permission boundary for workload roles in ${var.workload_name} (${var.environment})."
  policy      = data.aws_iam_policy_document.boundary.json
}

resource "aws_iam_role" "workload_baseline" {
  name                 = "${var.workload_name}-baseline"
  permissions_boundary = aws_iam_policy.workload_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.workload_baseline.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# A role isn't enough to put on an EC2 instance — it needs an instance
# profile as the actual attach point.
resource "aws_iam_instance_profile" "workload_baseline" {
  name = "${var.workload_name}-baseline"
  role = aws_iam_role.workload_baseline.name

  tags = var.tags
}

resource "aws_vpc" "workload" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.workload_name}-vpc"
  })
}

resource "aws_subnet" "private" {
  count                = 2
  vpc_id               = aws_vpc.workload.id
  cidr_block           = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone_id = var.availability_zone_ids[count.index]

  tags = merge(var.tags, {
    Name = "${var.workload_name}-private-${count.index + 1}"
    Tier = "private"
  })
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.workload.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index + 2)
  availability_zone       = var.availability_zone_ids[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.workload_name}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_flow_log" "workload" {
  log_destination_type = "s3"
  log_destination      = var.log_archive_bucket_arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.workload.id

  tags = var.tags
}

# Restrict the VPC default security group.
# No ingress or egress rules are permitted.
resource "aws_default_security_group" "workload" {
  vpc_id = aws_vpc.workload.id

  ingress = []
  egress  = []

  tags = merge(var.tags, {
    Name = "${var.workload_name}-default-deny"
  })
}

data "aws_region" "current" {}
