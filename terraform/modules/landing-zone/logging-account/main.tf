terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_kms_key" "logs" {
  description             = "CMK for centralized log archive (CloudTrail, Config, VPC Flow Logs)"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_key_policy" "logs" {
  key_id = aws_kms_key.logs.key_id
  policy = data.aws_iam_policy_document.logs_kms.json
}

resource "aws_kms_alias" "logs" {
  name          = "alias/log-archive"
  target_key_id = aws_kms_key.logs.key_id
}

data "aws_iam_policy_document" "logs_kms" {
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:Get*",
      "kms:List*",
      "kms:Put*",
      "kms:Revoke*",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:UpdateKeyDescription",
    ]
    resources = [aws_kms_key.logs.arn]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.log_archive_account_id}:root"]
    }
  }

  statement {
    sid    = "AllowCloudTrailUseOfKey"
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [aws_kms_key.logs.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_s3_bucket" "log_archive" {
  bucket = var.log_bucket_name
  # Object Lock can only be turned on at bucket creation — there is no
  # migration path to enable it on an existing bucket. Get this bit right
  # on the first apply.
  object_lock_enabled = true
  force_destroy       = false
  tags                = var.tags
}

resource "aws_s3_bucket" "log_archive_access_logs" {
  bucket = "${var.log_bucket_name}-access-logs"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "log_archive_access_logs" {
  bucket = aws_s3_bucket.log_archive_access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive_access_logs" {
  bucket = aws_s3_bucket.log_archive_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.logs.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "log_archive_access_logs" {
  bucket                  = aws_s3_bucket.log_archive_access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "log_archive_access_logs" {
  bucket = aws_s3_bucket.log_archive_access_logs.id

  rule {
    id     = "log-archive-access-logs-retention"
    status = "Enabled"

    filter { prefix = "" }

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_logging" "log_archive_access_logs" {
  bucket = aws_s3_bucket.log_archive_access_logs.id

  target_bucket = aws_s3_bucket.log_archive.id
  target_prefix = "log-archive-access-logs/"
}

resource "aws_s3_bucket_notification" "log_archive_access_logs" {
  bucket      = aws_s3_bucket.log_archive_access_logs.id
  eventbridge = true
}

resource "aws_s3_bucket_replication_configuration" "log_archive_access_logs" {
  bucket = aws_s3_bucket.log_archive_access_logs.id
  role   = aws_iam_role.log_archive_replication.arn

  rule {
    id     = "log-archive-access-logs-replication"
    status = "Enabled"

    filter {
      prefix = ""
    }

    destination {
      bucket = aws_s3_bucket.log_archive_replication.arn
    }
  }
}

resource "aws_s3_bucket" "log_archive_replication" {
  bucket = "${var.log_bucket_name}-replica"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "log_archive_replication" {
  bucket = aws_s3_bucket.log_archive_replication.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive_replication" {
  bucket = aws_s3_bucket.log_archive_replication.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.logs.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "log_archive_replication" {
  bucket                  = aws_s3_bucket.log_archive_replication.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "log_archive_replication" {
  bucket = aws_s3_bucket.log_archive_replication.id

  rule {
    id     = "log-archive-replication-retention"
    status = "Enabled"

    filter { prefix = "" }

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_logging" "log_archive_replication" {
  bucket = aws_s3_bucket.log_archive_replication.id

  target_bucket = aws_s3_bucket.log_archive_access_logs.id
  target_prefix = "log-archive-replication-access/"
}

resource "aws_s3_bucket_notification" "log_archive_replication" {
  bucket      = aws_s3_bucket.log_archive_replication.id
  eventbridge = true
}

resource "aws_s3_bucket_logging" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  target_bucket = aws_s3_bucket.log_archive_access_logs.id
  target_prefix = "logarchive-access/"
}

resource "aws_s3_bucket_notification" "log_archive" {
  bucket      = aws_s3_bucket.log_archive.id
  eventbridge = true
}

resource "aws_iam_role" "log_archive_replication" {
  name = "log-archive-replication-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "log_archive_replication" {
  name = "log-archive-replication-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket",
        "s3:GetObjectVersionForReplication",
        "s3:GetObjectVersionAcl",
        "s3:GetObjectVersionTagging",
        "s3:ReplicateObject",
        "s3:ReplicateDelete",
        "s3:ReplicateTags"
      ]
      Resource = [
        aws_s3_bucket.log_archive.arn,
        "${aws_s3_bucket.log_archive.arn}/*",
        aws_s3_bucket.log_archive_replication.arn,
        "${aws_s3_bucket.log_archive_replication.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "log_archive_replication" {
  role       = aws_iam_role.log_archive_replication.name
  policy_arn = aws_iam_policy.log_archive_replication.arn
}

resource "aws_s3_bucket_replication_configuration" "log_archive" {
  depends_on = [aws_s3_bucket_versioning.log_archive]
  bucket     = aws_s3_bucket.log_archive.id
  role       = aws_iam_role.log_archive_replication.arn

  rule {
    id     = "log-archive-replication"
    status = "Enabled"

    filter {
      prefix = ""
    }

    destination {
      bucket = aws_s3_bucket.log_archive_replication.arn
    }
  }
}

resource "aws_s3_bucket_versioning" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id
  versioning_configuration {
    status = "Enabled"
    # mfa_delete is intentionally NOT set here. The S3 API only accepts
    # MFADelete changes from the bucket owner's AWS account root user with
    # a live MFA code in the request — an assumed role (including the
    # GitHub Actions OIDC deploy role this repo uses everywhere else)
    # cannot set it, so leaving it in Terraform would break every apply.
    # Enable it once, out of band, after the bucket exists:
    #   aws s3api put-bucket-versioning --bucket <name> \
    #     --versioning-configuration Status=Enabled,MFADelete=Enabled \
    #     --mfa "arn:aws:iam::<account-id>:mfa/<device> <current-code>"
    # See docs/runbooks/access-review.md for who holds that root MFA device.
  }
}

resource "aws_s3_bucket_object_lock_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.object_lock_retention_days
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.logs.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "log_archive" {
  bucket                  = aws_s3_bucket.log_archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    id     = "log-archive-retention"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "log_archive_bucket" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.log_archive.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.log_archive.arn}/AWSLogs/${var.organization_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.log_archive.arn, "${aws_s3_bucket.log_archive.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyDeleteExceptRoot"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:DeleteBucket",
    ]
    resources = [aws_s3_bucket.log_archive.arn, "${aws_s3_bucket.log_archive.arn}/*"]
    condition {
      test     = "StringNotLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${var.log_archive_account_id}:root"]
    }
  }
}

resource "aws_s3_bucket_policy" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id
  policy = data.aws_iam_policy_document.log_archive_bucket.json
}

resource "aws_cloudwatch_log_group" "organization_cloudtrail" {
  name              = "/aws/cloudtrail/org-trail"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs.arn
}

resource "aws_iam_role" "organization_cloudtrail_logs" {
  name = "org-cloudtrail-cw-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "organization_cloudtrail_logs" {
  name = "org-cloudtrail-cw-policy"
  role = aws_iam_role.organization_cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = [
        aws_cloudwatch_log_group.organization_cloudtrail.arn,
        "${aws_cloudwatch_log_group.organization_cloudtrail.arn}:*"
      ]
    }]
  })
}

resource "aws_sns_topic" "cloudtrail_alerts" {
  name              = "org-cloudtrail-alerts"
  kms_master_key_id = aws_kms_key.logs.arn
}

resource "aws_cloudtrail" "organization" {
  name                          = "org-trail"
  s3_bucket_name                = aws_s3_bucket.log_archive.id
  s3_key_prefix                 = "cloudtrail"
  sns_topic_name                = aws_sns_topic.cloudtrail_alerts.name
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.logs.arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.organization_cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.organization_cloudtrail_logs.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
  }

  tags = var.tags

  depends_on = [aws_s3_bucket_policy.log_archive]
}

resource "aws_iam_role" "config" {
  name = "aws-config-recorder"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "this" {
  name     = "org-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "org-config-delivery"
  s3_bucket_name = aws_s3_bucket.log_archive.id
  s3_key_prefix  = "config"
  s3_kms_key_arn = aws_kms_key.logs.arn

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_aggregator" "organization" {
  name = "org-aggregator"

  organization_aggregation_source {
    all_regions = true
    role_arn    = aws_iam_role.config.arn
  }
}
