variable "management_account_id" {
  type        = string
  description = "The 12-digit AWS Organizations management account ID."
}

variable "security_account_id" {
  type        = string
  description = "12-digit AWS account ID to register as delegated admin for GuardDuty and Security Hub."
}

variable "organization_feature_set" {
  type        = string
  description = "Organization feature set. Use ALL for full org features (required for SCPs)."
  default     = "ALL"
  validation {
    condition     = contains(["ALL", "CONSOLIDATED_BILLING"], var.organization_feature_set)
    error_message = "organization_feature_set must be ALL or CONSOLIDATED_BILLING."
  }
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all resources."
  default     = {}
}
