output "workload_kms_key_arn" {
  description = "ARN of the workload CMK."
  value       = aws_kms_key.workload.arn
}

output "workload_vpc_id" {
  description = "Workload VPC ID."
  value       = aws_vpc.workload.id
}

output "workload_baseline_role_arn" {
  description = "ARN of the baseline workload IAM role."
  value       = aws_iam_role.workload_baseline.arn
}

output "workload_baseline_instance_profile_name" {
  description = "Name of the baseline instance profile — pass this to aws_instance.iam_instance_profile."
  value       = aws_iam_instance_profile.workload_baseline.name
}

output "permission_boundary_arn" {
  description = "ARN of the workload permission boundary policy."
  value       = aws_iam_policy.workload_boundary.arn
}
