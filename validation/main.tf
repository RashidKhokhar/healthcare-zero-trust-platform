terraform {
  required_version = ">= 1.6.0"
}

module "accounts" {
  source = "./accounts"
}

module "networking" {
  source = "./networking"
}

module "eks" {
  source = "./eks"
}

module "security" {
  source = "./security"
}

module "logging" {
  source = "./logging"
}

check "account_count" {
  assert {
    condition     = module.accounts.account_count == 5
    error_message = "Expected five AWS accounts."
  }
}

check "private_eks" {
  assert {
    condition = (
      module.eks.eks_architecture.private_endpoint &&
      !module.eks.eks_architecture.public_endpoint
    )
    error_message = "EKS must use a private endpoint."
  }
}

check "centralized_auditing" {
  assert {
    condition = (
      module.logging.logging_architecture.cloudtrail &&
      module.logging.logging_architecture.kms_encryption
    )
    error_message = "Centralized encrypted auditing is required."
  }
}

output "platform_summary" {
  value = {
    accounts = module.accounts.account_count
    network  = module.networking.network_architecture
    eks      = module.eks.eks_architecture
    security = module.security.security_architecture
    logging  = module.logging.logging_architecture
  }
}
