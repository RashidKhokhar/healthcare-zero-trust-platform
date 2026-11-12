# Module: `security-account`

Provisions the delegated security admin account: GuardDuty (org-wide, auto-enable, S3+Kubernetes+Malware Protection), Security Hub (CIS + AWS Foundational Security Best Practices standards), IAM Access Analyzer (organization scope), and Detective (org-wide). Delegated-admin registration itself happens in `org-baseline` — it's a management-account-only API call, so it can't run under this module's own (security-account) provider. Apply `org-baseline` first.

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `security_account_id` | string | — | yes | Delegated security admin account ID |
| `organization_id` | string | — | yes | AWS Organizations ID |
| `guardduty_finding_frequency` | string | `"FIFTEEN_MINUTES"` | no | Detector publish cadence |
| `tags` | map(string) | `{}` | no | Common tags |

## Outputs

| Name | Description |
|---|---|
| `guardduty_detector_id` | GuardDuty detector ID |
| `securityhub_account_id` | Security Hub account resource ID |
| `access_analyzer_arn` | IAM Access Analyzer ARN |
| `detective_graph_arn` | Detective behavior graph ARN |

## Dependencies

- `org-baseline` (needs `organization_id`)
- Runs in the **security** account with delegated admin permissions

## Compliance Controls Addressed

| Framework | Control | How |
|---|---|---|
| HIPAA | §164.312(b) Audit Controls | GuardDuty + Security Hub aggregation |
| NIST 800-53 | AU-6, SI-4 | Continuous monitoring, finding review |
| PCI-DSS v4.0 | 11.5 | Change detection via Config + Security Hub |

## Example

```hcl
module "security_account" {
  source              = "../../modules/security-account"
  security_account_id = "333333333333"
  organization_id     = module.org_baseline.organization_id
}
```
