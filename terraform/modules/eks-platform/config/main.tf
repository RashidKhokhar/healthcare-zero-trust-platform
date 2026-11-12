# HIPAA §164.308(a)(1)(ii)(A) — Risk Analysis / continuous monitoring.
# AWS Config continuously evaluates live resource configuration against
# a HIPAA-aligned rule set and flags drift the moment it happens, instead
# of relying on periodic manual audits.

resource "aws_s3_bucket" "config" {
  bucket = "${var.environment}-hipaa-config-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "config_access_logs" {
  bucket = "${var.environment}-hipaa-config-access-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "config_access_logs" {
  bucket = aws_s3_bucket.config_access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_access_logs" {
  bucket = aws_s3_bucket.config_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "config_access_logs" {
  bucket                  = aws_s3_bucket.config_access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "config_access_logs" {
  bucket = aws_s3_bucket.config_access_logs.id

  rule {
    id     = "config-access-logs-retention"
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

resource "aws_s3_bucket_logging" "config_access_logs" {
  bucket = aws_s3_bucket.config_access_logs.id

  target_bucket = aws_s3_bucket.config.id
  target_prefix = "config-access-logs/"
}

resource "aws_s3_bucket_notification" "config_access_logs" {
  bucket      = aws_s3_bucket.config_access_logs.id
  eventbridge = true
}

resource "aws_s3_bucket_replication_configuration" "config_access_logs" {
  bucket = aws_s3_bucket.config_access_logs.id
  role   = aws_iam_role.config_replication.arn

  rule {
    id     = "config-access-logs-replication"
    status = "Enabled"

    filter {
      prefix = ""
    }

    destination {
      bucket = aws_s3_bucket.config_replication.arn
    }
  }
}

resource "aws_s3_bucket" "config_replication" {
  bucket = "${var.environment}-hipaa-config-replica-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "config_replication" {
  bucket = aws_s3_bucket.config_replication.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_replication" {
  bucket = aws_s3_bucket.config_replication.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "config_replication" {
  bucket                  = aws_s3_bucket.config_replication.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "config_replication" {
  bucket = aws_s3_bucket.config_replication.id

  rule {
    id     = "config-replica-retention"
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

resource "aws_s3_bucket_logging" "config_replication" {
  bucket = aws_s3_bucket.config_replication.id

  target_bucket = aws_s3_bucket.config_access_logs.id
  target_prefix = "config-replication-access/"
}

resource "aws_s3_bucket_notification" "config_replication" {
  bucket      = aws_s3_bucket.config_replication.id
  eventbridge = true
}

resource "aws_s3_bucket_logging" "config" {
  bucket = aws_s3_bucket.config.id

  target_bucket = aws_s3_bucket.config_access_logs.id
  target_prefix = "config-access/"
}

resource "aws_s3_bucket_notification" "config" {
  bucket       = aws_s3_bucket.config.id
  eventbridge  = true
}

resource "aws_iam_role" "config_replication" {
  name = "${var.environment}-config-replication-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "config_replication" {
  name = "${var.environment}-config-replication-policy"
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
        aws_s3_bucket.config.arn,
        "${aws_s3_bucket.config.arn}/*",
        aws_s3_bucket.config_replication.arn,
        "${aws_s3_bucket.config_replication.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_replication" {
  role       = aws_iam_role.config_replication.name
  policy_arn = aws_iam_policy.config_replication.arn
}

resource "aws_s3_bucket_replication_configuration" "config" {
  depends_on = [aws_s3_bucket_versioning.config]
  bucket     = aws_s3_bucket.config.id
  role       = aws_iam_role.config_replication.arn

  rule {
    id     = "config-replication"
    status = "Enabled"

    filter {
      prefix = ""
    }

    destination {
      bucket = aws_s3_bucket.config_replication.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "config" {
  name = "${var.environment}-config-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "this" {
  name     = "${var.environment}-hipaa-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "${var.environment}-hipaa-delivery"
  s3_bucket_name = aws_s3_bucket.config.id
  depends_on     = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}

# HIPAA-relevant managed rules — encryption, public access, and logging
# checks that map directly to the controls in COMPLIANCE.md
resource "aws_config_config_rule" "s3_encrypted" {
  name = "s3-bucket-server-side-encryption-enabled"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }
  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_config_rule" "s3_public_read_prohibited" {
  name = "s3-bucket-public-read-prohibited"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }
  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_config_rule" "rds_encrypted" {
  name = "rds-storage-encrypted"
  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }
  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_config_rule" "iam_no_wildcard" {
  name = "iam-policy-no-statements-with-admin-access"
  source {
    owner             = "AWS"
    source_identifier = "IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS"
  }
  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_config_rule" "cloudtrail_enabled" {
  name = "cloudtrail-enabled"
  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }
  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_config_rule" "eks_endpoint_no_public_access" {
  name = "eks-endpoint-no-public-access"
  source {
    owner             = "AWS"
    source_identifier = "EKS_ENDPOINT_NO_PUBLIC_ACCESS"
  }
  depends_on = [aws_config_configuration_recorder.this]
}

data "aws_caller_identity" "current" {}

# Enable versioning for AWS Config history.
resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt AWS Config logs with an AWS managed KMS key.
resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Retain AWS Config logs for 365 days.
# Adjust retention to match actual compliance requirements.
resource "aws_s3_bucket_lifecycle_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    id     = "config-log-retention"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
