# HIPAA §164.312(b) / HITRUST 06.d: comprehensive, tamper-evident audit
# trail of every API call in the account. Log file validation lets you
# cryptographically prove logs haven't been altered after the fact.

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.environment}-hipaa-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "cloudtrail_access_logs" {
  bucket = "${var.environment}-hipaa-cloudtrail-access-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "cloudtrail_access_logs" {
  bucket = aws_s3_bucket.cloudtrail_access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_access_logs" {
  bucket = aws_s3_bucket.cloudtrail_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_access_logs" {
  bucket                  = aws_s3_bucket.cloudtrail_access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_access_logs" {
  bucket = aws_s3_bucket.cloudtrail_access_logs.id

  rule {
    id     = "cloudtrail-access-logs-retention"
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

resource "aws_s3_bucket_logging" "cloudtrail_access_logs" {
  bucket = aws_s3_bucket.cloudtrail_access_logs.id

  target_bucket = aws_s3_bucket.cloudtrail.id
  target_prefix = "cloudtrail-access-logs/"
}

resource "aws_s3_bucket_notification" "cloudtrail_access_logs" {
  bucket      = aws_s3_bucket.cloudtrail_access_logs.id
  eventbridge = true
}

resource "aws_s3_bucket_replication_configuration" "cloudtrail_access_logs" {
  bucket = aws_s3_bucket.cloudtrail_access_logs.id
  role   = aws_iam_role.cloudtrail_replication.arn

  rule {
    id     = "cloudtrail-access-logs-replication"
    status = "Enabled"

    filter {
      prefix = ""
    }

    destination {
      bucket = aws_s3_bucket.cloudtrail_replication.arn
    }
  }
}

resource "aws_s3_bucket" "cloudtrail_replication" {
  bucket = "${var.environment}-hipaa-cloudtrail-replica-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "cloudtrail_replication" {
  bucket = aws_s3_bucket.cloudtrail_replication.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_replication" {
  bucket = aws_s3_bucket.cloudtrail_replication.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_replication" {
  bucket                  = aws_s3_bucket.cloudtrail_replication.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_replication" {
  bucket = aws_s3_bucket.cloudtrail_replication.id

  rule {
    id     = "cloudtrail-replica-retention"
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

resource "aws_s3_bucket_logging" "cloudtrail_replication" {
  bucket = aws_s3_bucket.cloudtrail_replication.id

  target_bucket = aws_s3_bucket.cloudtrail_access_logs.id
  target_prefix = "cloudtrail-replication-access/"
}

resource "aws_s3_bucket_notification" "cloudtrail_replication" {
  bucket      = aws_s3_bucket.cloudtrail_replication.id
  eventbridge = true
}

resource "aws_s3_bucket_logging" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  target_bucket = aws_s3_bucket.cloudtrail_access_logs.id
  target_prefix = "cloudtrail-access/"
}

resource "aws_s3_bucket_notification" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  eventbridge = true
}

resource "aws_iam_role" "cloudtrail_replication" {
  name = "${var.environment}-cloudtrail-replication-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "cloudtrail_replication" {
  name = "${var.environment}-cloudtrail-replication-policy"
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
        aws_s3_bucket.cloudtrail.arn,
        "${aws_s3_bucket.cloudtrail.arn}/*",
        aws_s3_bucket.cloudtrail_replication.arn,
        "${aws_s3_bucket.cloudtrail_replication.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudtrail_replication" {
  role       = aws_iam_role.cloudtrail_replication.name
  policy_arn = aws_iam_policy.cloudtrail_replication.arn
}

resource "aws_s3_bucket_replication_configuration" "cloudtrail" {
  depends_on = [aws_s3_bucket_versioning.cloudtrail]
  bucket     = aws_s3_bucket.cloudtrail.id
  role       = aws_iam_role.cloudtrail_replication.arn

  rule {
    id     = "cloudtrail-replication"
    status = "Enabled"

    filter {
      prefix = ""
    }

    destination {
      bucket = aws_s3_bucket.cloudtrail_replication.arn
    }
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled" # HIPAA §164.312(c)(1) integrity controls
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/${var.environment}/cloudtrail"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "cloudtrail-retention"
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

resource "aws_sns_topic" "cloudtrail_alerts" {
  name              = "${var.environment}-cloudtrail-alerts"
  kms_master_key_id = var.kms_key_arn
}

resource "aws_iam_role" "cloudtrail_cw" {
  name = "${var.environment}-cloudtrail-cw-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cw" {
  name = "${var.environment}-cloudtrail-cw-policy"
  role = aws_iam_role.cloudtrail_cw.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

resource "aws_cloudtrail" "org" {
  name                          = "${var.environment}-hipaa-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  sns_topic_name                = aws_sns_topic.cloudtrail_alerts.name
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true # tamper-evidence
  kms_key_id                    = var.kms_key_arn

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cw.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

data "aws_caller_identity" "current" {}
