terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Management account
provider "aws" {
  alias   = "management"
  region  = var.aws_region
  profile = "management"
}

# Security account
provider "aws" {
  alias   = "security"
  region  = var.aws_region
  profile = "security"
}

# Logging account
provider "aws" {
  alias   = "logging"
  region  = var.aws_region
  profile = "logging"
}

# Network account
provider "aws" {
  alias   = "network"
  region  = var.aws_region
  profile = "network"
}

# Workload account
provider "aws" {
  alias   = "workload"
  region  = var.aws_region
  profile = "workload"
}
