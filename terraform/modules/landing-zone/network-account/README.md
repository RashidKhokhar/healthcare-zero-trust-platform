# Module: `network-account`

Provisions the shared network account: Transit Gateway (with controlled routing), RAM share to the organization, Route 53 Resolver DNS Firewall, a shared-services VPC, and VPC Flow Logs to the log archive.

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `network_account_id` | string | — | yes | Network account ID |
| `transit_gateway_asn` | number | `64512` | no | Amazon-side ASN |
| `shared_services_vpc_cidr` | string | `"10.0.0.0/20"` | no | Shared VPC CIDR |
| `organization_arn` | string | — | yes | Org ARN for RAM sharing |
| `log_archive_bucket_arn` | string | — | yes | Flow Log destination |
| `blocked_domains` | list(string) | `[]` | no | DNS Firewall block list |
| `tags` | map(string) | `{}` | no | Common tags |

## Outputs

| Name | Description |
|---|---|
| `transit_gateway_id` | Transit Gateway ID |
| `transit_gateway_arn` | Transit Gateway ARN |
| `ram_share_arn` | RAM share ARN |
| `shared_services_vpc_id` | Shared services VPC ID |
| `dns_firewall_rule_group_id` | DNS Firewall rule group ID |

## Dependencies

- `org-baseline` (needs `organization_arn`)
- `logging-account` (needs `log_archive_bucket_arn`)
- Runs in the **network** account

## Compliance Controls Addressed

| Framework | Control | How |
|---|---|---|
| NIST 800-53 | SC-7 Boundary Protection | Transit Gateway hub-and-spoke, DNS Firewall |
| PCI-DSS v4.0 | 1.2, 1.3 | Controlled inbound/outbound network paths |

## Example

```hcl
module "network_account" {
  source                 = "../../modules/network-account"
  network_account_id     = "444444444444"
  organization_arn       = module.org_baseline.organization_arn
  log_archive_bucket_arn = module.logging_account.log_bucket_arn
  blocked_domains        = ["known-bad.example.com"]
}
```
