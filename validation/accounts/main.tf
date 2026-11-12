terraform {
  required_version = ">= 1.6.0"
}

locals {
  accounts = {
    management = {
      purpose = "AWS Organizations and governance"
    }
    security = {
      purpose = "GuardDuty, Security Hub and compliance"
    }
    logging = {
      purpose = "Centralized CloudTrail and audit logs"
    }
    network = {
      purpose = "Shared networking and connectivity"
    }
    workload = {
      purpose = "Private EKS and healthcare application"
    }
  }
}

output "account_architecture" {
  description = "Simulated AWS account architecture"
  value       = local.accounts
}

output "account_count" {
  value = length(local.accounts)
}
