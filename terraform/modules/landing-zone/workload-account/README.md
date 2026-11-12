# Module: `workload-account`

Provisions per-workload baseline: KMS CMK with rotation, account-level S3 Public Access Block, a permission boundary policy that denies identity/org actions and unencrypted S3 writes, a baseline IAM role attached to that boundary with an instance profile so it can actually be assigned to an EC2 instance, VPC with private/public subnets across 2 AZs, and VPC Flow Logs.

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `workload_account_id` | string | — | yes | Workload account ID |
| `workload_name` | string | — | yes | Short workload identifier |
| `vpc_cidr` | string | `"10.10.0.0/16"` | no | Workload VPC CIDR |
| `environment` | string | — | yes | `dev`, `prod`, or `shared` |
| `log_archive_bucket_arn` | string | — | yes | Flow Log destination |
| `tags` | map(string) | `{}` | no | Common tags |

## Outputs

| Name | Description |
|---|---|
| `workload_kms_key_arn` | Workload CMK ARN |
| `workload_vpc_id` | Workload VPC ID |
| `workload_baseline_role_arn` | Baseline role ARN |
| `workload_baseline_instance_profile_name` | Instance profile name — pass to `aws_instance.iam_instance_profile` |
| `permission_boundary_arn` | Permission boundary policy ARN |

## Dependencies

- `logging-account` (Flow Log destination)
- Runs in the **workload** account

## Compliance Controls Addressed

| Framework | Control | How |
|---|---|---|
| HIPAA | §164.312(a)(1), §164.312(a)(2)(iv), §164.312(e)(1) | Access control, encryption, transmission security |
| NIST 800-53 | AC-6, SC-13, SC-28 | Least privilege boundary, KMS encryption at rest |
| PCI-DSS v4.0 | 3.5, 7.2 | Key protection, need-to-know access |

## Example

```hcl
module "workload_dev" {
  source                 = "../../modules/workload-account"
  workload_account_id    = "555555555555"
  workload_name          = "acme-app"
  environment            = "dev"
  vpc_cidr               = "10.20.0.0/16"
  log_archive_bucket_arn = module.logging_account.log_bucket_arn
}
```
