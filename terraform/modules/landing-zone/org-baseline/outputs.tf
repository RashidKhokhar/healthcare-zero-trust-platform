output "organization_id" {
  description = "The AWS Organizations ID (o-xxxxxxxxxx)."
  value       = aws_organizations_organization.this.id
}

output "organization_arn" {
  description = "The ARN of the AWS Organization."
  value       = aws_organizations_organization.this.arn
}

output "organization_root_id" {
  description = "The root ID of the organization."
  value       = aws_organizations_organization.this.roots[0].id
}

output "ou_ids" {
  description = "Map of OU name to OU ID."
  value = {
    security       = aws_organizations_organizational_unit.security.id
    infrastructure = aws_organizations_organizational_unit.infrastructure.id
    workloads      = aws_organizations_organizational_unit.workloads.id
    sandbox        = aws_organizations_organizational_unit.sandbox.id
  }
}

output "scp_policy_ids" {
  description = "Map of SCP name to SCP policy ID."
  value = {
    deny_leave_org      = aws_organizations_policy.deny_leave_org.id
    deny_root_user      = aws_organizations_policy.deny_root_user.id
    deny_unencrypted_s3 = aws_organizations_policy.deny_unencrypted_s3.id
  }
}
