variable "security_account_id" {
  type        = string
  description = "12-digit AWS account ID delegated as the security admin."
}

variable "guardduty_finding_frequency" {
  type        = string
  description = "GuardDuty finding publishing frequency."
  default     = "FIFTEEN_MINUTES"
  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.guardduty_finding_frequency)
    error_message = "guardduty_finding_frequency must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}
