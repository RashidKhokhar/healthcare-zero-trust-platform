variable "workload_account_id" {
  type        = string
  description = "12-digit workload account ID."
}

variable "workload_name" {
  type        = string
  description = "Short workload identifier (used as prefix on resources)."
}

variable "vpc_cidr" {
  type        = string
  description = "Workload VPC CIDR."
  default     = "10.10.0.0/16"
}

variable "environment" {
  type        = string
  description = "Environment tier."
  validation {
    condition     = contains(["dev", "prod", "shared"], var.environment)
    error_message = "environment must be dev, prod, or shared."
  }
}

variable "log_archive_bucket_arn" {
  type        = string
  description = "S3 bucket ARN in the log archive for VPC Flow Logs."
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}

variable "availability_zone_ids" {
  description = "Exactly two AWS Availability Zone IDs, configured per account and region."
  type        = list(string)

  validation {
    condition     = length(var.availability_zone_ids) == 2 && length(distinct(var.availability_zone_ids)) == 2
    error_message = "Provide exactly two distinct AZ IDs."
  }
}
