terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

check "applying_into_network_account" {
  assert {
    condition     = data.aws_caller_identity.current.account_id == var.network_account_id
    error_message = "Provider is authenticated to account ${data.aws_caller_identity.current.account_id}, but network_account_id is set to ${var.network_account_id}. Refusing to apply into the wrong account."
  }
}

resource "aws_ec2_transit_gateway" "hub" {
  description                     = "Landing zone shared Transit Gateway"
  amazon_side_asn                 = var.transit_gateway_asn
  auto_accept_shared_attachments  = "disable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(var.tags, {
    Name = "landing-zone-tgw"
  })
}

resource "aws_ec2_transit_gateway_route_table" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.hub.id
  tags = merge(var.tags, {
    Name = "tgw-rt-prod"
  })
}

resource "aws_ec2_transit_gateway_route_table" "nonprod" {
  transit_gateway_id = aws_ec2_transit_gateway.hub.id
  tags = merge(var.tags, {
    Name = "tgw-rt-nonprod"
  })
}

resource "aws_ec2_transit_gateway_route_table" "shared" {
  transit_gateway_id = aws_ec2_transit_gateway.hub.id
  tags = merge(var.tags, {
    Name = "tgw-rt-shared"
  })
}

resource "aws_ram_resource_share" "tgw_share" {
  name                      = "tgw-share"
  allow_external_principals = false
  tags                      = var.tags
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn       = aws_ec2_transit_gateway.hub.arn
  resource_share_arn = aws_ram_resource_share.tgw_share.arn
}

resource "aws_ram_principal_association" "org" {
  principal          = var.organization_arn
  resource_share_arn = aws_ram_resource_share.tgw_share.arn
}

resource "aws_route53_resolver_firewall_domain_list" "blocked" {
  name    = "landing-zone-blocked-domains"
  domains = var.blocked_domains
  tags    = var.tags
}

resource "aws_route53_resolver_firewall_rule_group" "primary" {
  name = "landing-zone-fw-rules"
  tags = var.tags
}

resource "aws_route53_resolver_firewall_rule" "block" {
  name                    = "block-listed-domains"
  action                  = "BLOCK"
  block_response          = "NXDOMAIN"
  firewall_domain_list_id = aws_route53_resolver_firewall_domain_list.blocked.id
  firewall_rule_group_id  = aws_route53_resolver_firewall_rule_group.primary.id
  priority                = 100
}

# The rule group above does nothing until it's associated with a VPC.
# This was the missing piece — without it, DNS Firewall is provisioned
# but not actually filtering anything.
resource "aws_route53_resolver_firewall_rule_group_association" "shared_services" {
  name                   = "shared-services-dns-firewall"
  firewall_rule_group_id = aws_route53_resolver_firewall_rule_group.primary.id
  vpc_id                 = aws_vpc.shared_services.id
  priority               = 101
  mutation_protection    = "DISABLED"
}

resource "aws_vpc" "shared_services" {
  cidr_block           = var.shared_services_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "shared-services-vpc"
  })
}

resource "aws_default_security_group" "shared_services" {
  vpc_id = aws_vpc.shared_services.id

  ingress = []
  egress  = []
}

resource "aws_flow_log" "shared_services" {
  log_destination_type = "s3"
  log_destination      = var.log_archive_bucket_arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.shared_services.id

  tags = var.tags
}
