# Module: `logging-account`

Provisions the centralized log archive account: KMS CMK, immutable S3 bucket (Object Lock compliance mode — enabled at creation, since AWS doesn't allow adding it after the fact — plus versioning), organization-level CloudTrail with log file validation, and AWS Config recorder + delivery + organization aggregator. MFA Delete on the bucket is a one-time manual step outside Terraform — see the comment in `main.tf` for the exact command; the S3 API only accepts that specific setting from the account root user with a live MFA code, which an assumed role (including this repo's own deploy role) can't provide.

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `log_bucket_name` | string | — | yes | Globally unique S3 bucket name |
| `log_archive_account_id` | string | — | yes | 12-digit log archive account ID |
| `organization_id` | string | — | yes | AWS Organizations ID |
| `kms_deletion_window` | number | `30` | no | Days before KMS key deletion |
| `object_lock_retention_days` | number | `2555` | no | Immutable retention in days |
| `tags` | map(string) | `{}` | no | Common tags |

## Outputs

| Name | Description |
|---|---|
| `log_bucket_name` | Log archive bucket name |
| `log_bucket_arn` | Log archive bucket ARN |
| `cloudtrail_arn` | Organization CloudTrail ARN |
| `kms_key_arn` | Log-archive KMS key ARN |
| `config_aggregator_arn` | Config aggregator ARN |

## Dependencies

- `org-baseline` must be applied first (needs `organization_id`)
- Runs in the **log archive** account

## Compliance Controls Addressed

| Framework | Control | How |
|---|---|---|
| HIPAA | §164.312(b), §164.312(c)(1) | Immutable audit trail with Object Lock |
| NIST 800-53 | AU-2, AU-9, AU-12 | Org trail, log integrity, data event logging |
| PCI-DSS v4.0 | 10.2, 10.3, 10.5 | Log content + immutability + KMS encryption |

## Example

```hcl
module "logging_account" {
  source                     = "../../modules/logging-account"
  log_bucket_name            = "acme-log-archive-9f2b"
  log_archive_account_id     = "222222222222"
  organization_id            = module.org_baseline.organization_id
  object_lock_retention_days = 2555
}
```
