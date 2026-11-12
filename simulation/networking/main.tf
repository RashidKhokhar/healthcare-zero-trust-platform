terraform {
  required_version = ">= 1.6.0"
}

locals {
  network = {
    account       = "network"
    vpc_cidr      = "10.20.0.0/16"
    private_zones = ["us-east-1a", "us-east-1b"]
    public_access = false
    flow_logs     = true
  }
}

output "network_architecture" {
  value = local.network
}
