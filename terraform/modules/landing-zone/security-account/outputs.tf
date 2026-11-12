output "guardduty_detector_id" {
  description = "GuardDuty detector ID in the security account."
  value       = aws_guardduty_detector.primary.id
}

output "securityhub_account_id" {
  description = "Security Hub account resource ID."
  value       = aws_securityhub_account.primary.id
}

output "access_analyzer_arn" {
  description = "IAM Access Analyzer (organization scope) ARN."
  value       = aws_accessanalyzer_analyzer.org.arn
}

output "detective_graph_arn" {
  description = "Detective behavior graph ARN."
  value       = aws_detective_graph.primary.graph_arn
}
