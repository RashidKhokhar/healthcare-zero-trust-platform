output "log_bucket_name" {
  description = "Name of the log archive S3 bucket."
  value       = aws_s3_bucket.log_archive.id
}

output "log_bucket_arn" {
  description = "ARN of the log archive S3 bucket."
  value       = aws_s3_bucket.log_archive.arn
}

output "cloudtrail_arn" {
  description = "ARN of the organization CloudTrail."
  value       = aws_cloudtrail.organization.arn
}

output "kms_key_arn" {
  description = "ARN of the log-archive KMS key."
  value       = aws_kms_key.logs.arn
}

output "config_aggregator_arn" {
  description = "ARN of the AWS Config organization aggregator."
  value       = aws_config_configuration_aggregator.organization.arn
}
