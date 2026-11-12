# Module: `org-baseline`

Provisions the AWS Organizations foundation for the landing zone: the org itself, the top-level OUs, baseline Service Control Policies (SCPs), a strict account password policy for the management account, and delegated-admin registration for GuardDuty and Security Hub (this has to run in the management account, which is why it's here and not in `security-account`).

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `management_account_id` | string | — | yes | 12-digit management account ID |
| `security_account_id` | string | — | yes | 12-digit account ID to register as delegated admin for GuardDuty and Security Hub |
| `organization_feature_set` | string | `"ALL"` | no | `ALL` (required for SCPs) or `CONSOLIDATED_BILLING` |
| `tags` | map(string) | `{}` | no | Common tags |

## Outputs

| Name | Description |
|---|---|
| `organization_id` | The AWS Organizations ID |
| `organization_arn` | ARN of the organization |
| `organization_root_id` | Root ID |
| `ou_ids` | Map of OU name → OU ID |
| `scp_policy_ids` | Map of SCP name → policy ID |

## Dependencies

- Terraform `>= 1.6`
- AWS provider `~> 5.0`
- Credentials for the **management** account

## Compliance Controls Addressed

| Framework | Control | How |
|---|---|---|
| HIPAA | §164.312(a)(1) Access Control | SCPs enforce deny-by-default at OU level |
| NIST 800-53 | AC-2, AC-6 | Password policy + SCP-enforced least privilege |
| PCI-DSS v4.0 | 7.2, 8.3 | OU-scoped access boundaries, strong password policy |

## Example

```hcl
module "org_baseline" {
  source                = "../../modules/org-baseline"
  management_account_id = "111111111111"
  security_account_id   = "333333333333"
  tags = {
    ManagedBy = "Terraform"
    Repo      = "aws-regulated-landing-zone"
  }
}
```
