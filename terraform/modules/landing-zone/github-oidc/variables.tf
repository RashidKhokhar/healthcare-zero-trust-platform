variable "github_org" {
  type        = string
  description = "GitHub organization or user (e.g., Patriot7Six)."
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (e.g., aws-regulated-landing-zone)."
}

variable "github_branch" {
  type        = string
  description = "Branch allowed to assume the deploy role."
  default     = "main"
}

variable "state_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket holding Terraform state."
}

variable "state_lock_table_arn" {
  type        = string
  description = "ARN of the DynamoDB table used for Terraform state locking."
}

variable "deploy_role_name" {
  type        = string
  description = "Name of the IAM role assumed by GitHub Actions."
  default     = "github-actions-deploy"
}

variable "member_account_role_name" {
  type        = string
  description = "IAM role name the deploy role assumes into every other account in the org (e.g., OrganizationAccountAccessRole). Must match the role name used by the provider aliases in environments/*/main.tf."
  default     = "OrganizationAccountAccessRole"
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}
