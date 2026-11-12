variable "log_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for the log archive."
}

variable "log_archive_account_id" {
  type        = string
  description = "12-digit account ID of the log archive account."
}

variable "organization_id" {
  type        = string
  description = "AWS Organizations ID (o-xxxxxxxxxx) for CloudTrail bucket policy scoping."
}

variable "kms_deletion_window" {
  type        = number
  description = "Days before scheduled KMS key deletion."
  default     = 30
}

variable "object_lock_retention_days" {
  type        = number
  description = "Object Lock retention period in days for immutable log storage."
  default     = 2555 # 7 years
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all resources."
  default     = {}
}
