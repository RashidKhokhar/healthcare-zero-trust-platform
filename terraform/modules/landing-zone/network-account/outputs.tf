output "transit_gateway_id" {
  description = "ID of the shared Transit Gateway."
  value       = aws_ec2_transit_gateway.hub.id
}

output "transit_gateway_arn" {
  description = "ARN of the shared Transit Gateway."
  value       = aws_ec2_transit_gateway.hub.arn
}

output "ram_share_arn" {
  description = "RAM resource share ARN for the Transit Gateway."
  value       = aws_ram_resource_share.tgw_share.arn
}

output "shared_services_vpc_id" {
  description = "VPC ID of the shared services VPC."
  value       = aws_vpc.shared_services.id
}

output "dns_firewall_rule_group_id" {
  description = "Route 53 Resolver DNS Firewall rule group ID."
  value       = aws_route53_resolver_firewall_rule_group.primary.id
}
