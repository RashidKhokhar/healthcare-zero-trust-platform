# Module: `github-oidc`

Creates the AWS IAM OpenID Connect (OIDC) identity provider trusting `token.actions.githubusercontent.com`, plus a scoped IAM role that GitHub Actions can assume to deploy this landing zone. **No IAM users. No static access keys.**

## Trust Scoping

The role trust policy is scoped by `sub` claim to a specific GitHub org, repo, and branch, using `StringEquals` (not `StringLike`) — no wildcards:

```
repo:<org>/<repo>:ref:refs/heads/<branch>
```

Fork PRs and other branches cannot assume the role.

## What this role can do

Beyond the Terraform-state and infrastructure-service permissions, this role can `sts:AssumeRole` into every other account in the org via `arn:aws:iam::*:role/OrganizationAccountAccessRole` — that's what lets the environment configs' provider aliases (`aws.security`, `aws.network`, `aws.log_archive`, `aws.workload_*`) actually authenticate. IAM and Organizations permissions are an explicit action list, not `iam:*` / `organizations:*` — see [ADR-0005](../../../docs/decision-records/0005-ci-deploy-role-scope.md) for why and exactly what's granted.

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `github_org` | string | — | yes | GitHub org or user |
| `github_repo` | string | — | yes | Repository name |
| `github_branch` | string | `"main"` | no | Allowed branch |
| `state_bucket_arn` | string | — | yes | Terraform state bucket ARN |
| `state_lock_table_arn` | string | — | yes | Terraform lock table ARN |
| `deploy_role_name` | string | `"github-actions-deploy"` | no | Deploy role name |
| `member_account_role_name` | string | `"OrganizationAccountAccessRole"` | no | Role name this role assumes into other accounts — must match the environment configs' provider aliases |
| `tags` | map(string) | `{}` | no | Common tags |

## Outputs

| Name | Description |
|---|---|
| `oidc_provider_arn` | OIDC provider ARN |
| `deploy_role_arn` | Deploy role ARN (put this in `role-to-assume` in your workflow) |
| `deploy_role_name` | Deploy role name |

## Dependencies

- Runs in the account that will host the deploy role (typically the management or a dedicated CI account)

## Compliance Controls Addressed

| Framework | Control | How |
|---|---|---|
| HIPAA | §164.312(a)(1), §164.312(d) | Federated auth, no shared credentials |
| NIST 800-53 | AC-2, IA-2, IA-5 | Federated identity, no long-lived authenticators |

## Example

```hcl
module "github_oidc" {
  source               = "../../modules/github-oidc"
  github_org           = "Patriot7Six"
  github_repo          = "aws-regulated-landing-zone"
  github_branch        = "main"
  state_bucket_arn     = "arn:aws:s3:::acme-tfstate"
  state_lock_table_arn = "arn:aws:dynamodb:us-east-1:111111111111:table/tf-locks"
}
```

## Reference

See [ADR-0003: GitHub Actions to AWS via OIDC Federation](../../../docs/decision-records/0003-github-oidc-federation.md).
