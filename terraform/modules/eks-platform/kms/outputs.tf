output "eks_secrets_key_arn" {
  value = aws_kms_key.eks_secrets.arn
}

output "rds_key_arn" {
  value = aws_kms_key.rds.arn
}

output "cloudtrail_key_arn" {
  value = aws_kms_key.cloudtrail.arn
}
