terraform {
  required_version = ">= 1.6.0"
}

locals {
  logging = {
    account             = "logging"
    cloudtrail          = true
    centralized_s3_logs = true
    kms_encryption      = true
    log_retention_days  = 365
    vpc_flow_logs       = true
    eks_audit_logs      = true
  }
}

output "logging_architecture" {
  value = local.logging
}
