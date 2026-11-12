output "s3_bucket_name" {
  value = aws_s3_bucket.cloudtrail.id
}

output "trail_arn" {
  value = aws_cloudtrail.org.arn
}
