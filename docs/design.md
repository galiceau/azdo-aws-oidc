# Design

## Goal

Give Azure DevOps pipelines **temporary AWS access with no stored secret**, scoped per environment.

## Architecture

```
Azure DevOps                                   Target AWS account
┌───────────────────────────┐                 ┌──────────────────────────────────┐
│ Pipeline                  │                 │ IAM OIDC provider (issuer_url)   │
│  └─ AWS Toolkit task      │  1. JWT         │        │ validates signature     │
│      └─ Service connection├────────────────►│ STS AssumeRoleWithWebIdentity    │
│         AWS (OIDC)        │                 │        │ trust policy: aud + sub │
│  sub = sc://org/proj/name │  2. temp creds  │ IAM Role (least privilege)       │
│                           │◄────────────────┤                                  │
└───────────────────────────┘  3. API calls   └──────────────────────────────────┘
```

Once per account: one provider. Per environment: one role bound to one service connection (or a few).
See [architecture.md](architecture.md) for the diagrams.

## Trust contract

| Claim | Value | Enforced by |
|---|---|---|
| `iss` | Issuer URL (see `issuer_url`) | the IAM provider (provider URL) |
| `aud` | `api://AzureADTokenExchange` | `StringEquals <host>:aud` condition |
| `sub` | `sc://<organization>/<project>/<service connection>` | `StringEquals <host>:sub` condition |

Consequences:

- `sub` identifies the **service connection**, not the pipeline or the branch (unlike GitHub Actions). AWS cannot tell apart two pipelines using the same connection. Fine-grained separation happens **on the Azure DevOps side**: per-pipeline authorization, approvals and checks on the connection, protected branches.
- Rule: **one service connection and one role per environment** (dev / test / prod); never share a connection between prod and non-prod.
- `sub` is case sensitive and must match exactly (including spaces in project names).

## Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Split `oidc-provider` and `oidc-role` | An account can hold only one provider per URL; several roles must share it. A single "provider + role" module prevents having two roles in the same account (the second provider would fail: URL already registered). |
| D2 | `aws_iam_policy_document` for the trust policy | Native feature of the AWS provider, rather than hand-assembled JSON. |
| D3 | `Principal.Federated` = provider ARN (output) | Avoids rebuilding the ARN from account ID and URL. |
| D4 | `for_each` on static keys for policies and attachments | With `count`, removing one policy shifts the indexes and recreates the others. |
| D5 | No thumbprint by default | AWS validates the certificate chain with its trusted CA library; AWS provider >= 5.81 makes it optional. No `ignore_changes` needed. |
| D6 | Preconditions: at least one `sub`, never a bare `*` | A role without a `sub` condition would trust every connection of the organization. |
| D7 | No code generator | Generating HCL with a script (parsing tfvars) to work around the lack of `for_each` on providers is fragile. Instead: **one stack per account** (separate state and credentials), driven by a pipeline matrix. |
| D8 | `terraform test` + `mock_provider` | Validates the logic (sub, guard rails) without AWS credentials. |
| D9 | No `AdministratorAccess` by default | Least privilege is an explicit choice of the caller; the example combines a managed policy and a targeted `Deny`. |

## Multi-account deployment

Terraform does not allow `for_each` over providers. Chosen approach: the same `examples/account` stack runs **once per account**:

- S3 backend with one state key per account (`-backend-config="key=oidc/<account_id>.tfstate"`);
- `deployer_role_arn`: bootstrap role assumed in the target account (or ambient credentials already in the right account);
- an Azure DevOps job matrix (`strategy.matrix`) iterates over the accounts with one `*.tfvars` file per account.

Alternative to consider if the number of accounts grows: Terraform Stacks (`for_each` over deployments/providers).

## Risks and open points

1. **Deprecation of the `vstoken.dev.azure.com` issuer** (retirement announced for July 1, 2027, source: Microsoft Learn, *Configure workload identity*). That page explicitly targets *Azure Resource Manager* connections; I found no confirmation covering **AWS** connections. Verify before industrializing: create a test AWS service connection and read the issuer and subject it displays. The modules accept another issuer (`issuer_url`) and raw subjects (`subjects`); you would then need an additional provider (or replace the old one) and roles whose `sub` follows the new format.
2. **Creating service connections**: registering the AWS connection in OIDC mode is done in Azure DevOps (UI or API). I did not verify whether the `azuredevops` Terraform provider exposes this mode, so the guide describes the manual procedure.
3. **Bootstrap role**: the initial deployment needs IAM rights in the account (deployment role, SSO, or managed agent). Out of scope for this repository.

## Sources

- Microsoft Learn, *Set a Resource Manager workload identity service connection* (issuer deprecation).
- AWS DevOps Blog, *Use OpenID Connect with AWS Toolkit for Azure DevOps* (`aud`/`sub` trust policy, OIDC + toolkit).
- AWS Modernizing Blog, *How to federate into AWS from Azure DevOps using OpenID Connect*.
