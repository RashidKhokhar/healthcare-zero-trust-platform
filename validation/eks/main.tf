terraform {
  required_version = ">= 1.6.0"
}

locals {
  eks = {
    account                  = "workload"
    cluster_name             = "healthcare-secure-eks"
    network_account          = "network"
    private_endpoint         = true
    public_endpoint          = false
    node_subnets             = "private"
    secrets_encryption       = "AWS KMS"
    workload_identity        = "EKS Pod Identity"
    control_plane_audit_logs = true
    synthetic_patient_data   = true
  }
}

output "eks_architecture" {
  value = local.eks
}

check "private_cluster" {
  assert {
    condition     = local.eks.private_endpoint && !local.eks.public_endpoint
    error_message = "EKS public endpoint must be disabled."
  }
}
