terraform {
  required_version = ">= 1.6.0"
}

locals {
  security = {
    account            = "security"
    guardduty          = true
    security_hub       = true
    aws_config         = true
    prowler_scanning   = true
    vulnerability_scan = "Trivy"
    compliance_target  = "HIPAA Security Rule"
  }
}

output "security_architecture" {
  value = local.security
}
