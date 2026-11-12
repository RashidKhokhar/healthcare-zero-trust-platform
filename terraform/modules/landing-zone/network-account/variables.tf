variable "network_account_id" {
  type        = string
  description = "12-digit network account ID."
}

variable "transit_gateway_asn" {
  type        = number
  description = "Amazon-side ASN for the Transit Gateway."
  default     = 64512
}

variable "shared_services_vpc_cidr" {
  type        = string
  description = "CIDR block for the shared services VPC."
  default     = "10.0.0.0/20"
}

variable "organization_arn" {
  type        = string
  description = "AWS Organization ARN — used for RAM sharing of the Transit Gateway."
}

variable "log_archive_bucket_arn" {
  type        = string
  description = "S3 bucket ARN in the log archive account for VPC Flow Logs."
}

variable "blocked_domains" {
  type        = list(string)
  description = "Domains to block at Route 53 Resolver DNS Firewall."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}
