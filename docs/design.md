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

1. **Azure DevOps issuer retirement: impact on AWS connections is not settled.**
   What is documented (Microsoft DevOps Blog, 22 June 2026, and Microsoft Learn):
   - Since November 2025, *new* workload identity federation service connections use the Microsoft Entra issuer (`https://login.microsoftonline.com/<tenant-id>/v2.0`). The Azure DevOps issuer (`https://vstoken.dev.azure.com/<org-guid>`) is deprecated from July 1, 2026 and reaches end of life on **July 1, 2027**.
   - The announcement is scoped to connections that use single-tenant Microsoft Entra applications or managed identities, i.e. Azure connections. AWS service connections are neither.
   - Microsoft's comparison table says a token from the Entra issuer "can only be exchanged for Microsoft Entra access tokens", whereas the Azure DevOps issuer token can be exchanged with other identity providers. That is the property AWS STS federation relies on.
   - The Entra issuer uses another subject shape: `<microsoft entra prefix>/sc/<organization id>/<service connection id>` (immutable ids instead of names).
   - The AWS Toolkit for Azure DevOps tracks the question in [aws-toolkit-azure-devops#614](https://github.com/aws/aws-toolkit-azure-devops/issues/614). The only analysis in that thread (a commenter reading the toolkit code, not an official statement) says the toolkit forwards whatever token Azure DevOps mints to STS without checking the issuer, so the timing depends on Microsoft, not on a toolkit change.

   Conclusion: today (the official AWS blog flow) AWS connections still show the `vstoken.dev.azure.com` issuer. Whether Microsoft will move them to the Entra issuer, and whether AWS STS will still accept such a token, is **not confirmed**. Before industrializing: create a test AWS service connection, read the issuer and subject in the `OIDC Token generated` log line (see [azure-devops-setup.md](azure-devops-setup.md)), and follow issue #614.

   Mitigations built in: `issuer_url` is a variable, `subjects` accepts raw values (e.g. the Entra subject shape), providers and roles are separate modules, so a second provider and new trust conditions can be added without recreating roles.

   Fallbacks if AWS stops accepting Azure DevOps tokens (not implemented here):
   - Self-hosted agents on EC2 with an instance profile (no federation needed; the toolkit picks up instance-metadata credentials).
   - Microsoft Entra as the identity provider: a managed identity or app registration gets an Entra token for a custom audience, and AWS trusts `sts.windows.net/<tenant-id>/` (flow described in the AWS DevOps Blog post below).
2. **Creating service connections**: registering the AWS connection in OIDC mode is done in Azure DevOps (UI or API; the AWS blog points to a GitHub comment on the toolkit repository for CLI/API automation). I did not verify whether the `azuredevops` Terraform provider exposes this mode, so the guide describes the manual procedure.
3. **Bootstrap role**: the initial deployment needs IAM rights in the account (deployment role, SSO, or managed agent). Out of scope for this repository.
4. **Toolkit version**: the OIDC option requires AWS Toolkit for Azure DevOps 1.15.0 or later.

## Sources

- AWS Modernizing Blog, [How to federate into AWS from Azure DevOps using OpenID Connect](https://aws.amazon.com/blogs/modernizing-with-aws/how-to-federate-into-aws-from-azure-devops-using-openid-connect/) (reference flow: issuer, audience, subject, trust policy, `aws.rolecredential.maxduration`).
- AWS DevOps Blog, [Use OpenID Connect with AWS Toolkit for Azure DevOps](https://aws.amazon.com/blogs/devops/use-openid-connect-with-aws-toolkit-for-azure-devops-to-perform-aws-codedeploy-deployments/) (Microsoft Entra as identity provider, `sts.windows.net` flavour).
- Microsoft DevOps Blog, [Retirement of Azure DevOps issuer in Workload identity federation service connections](https://devblogs.microsoft.com/devops/retirement-of-azure-devops-issuer-in-workload-identity-federation-service-connections/).
- Microsoft Learn, [Troubleshoot workload identity service connections](https://learn.microsoft.com/en-us/azure/devops/pipelines/release/troubleshoot-workload-identity) (issuer/subject comparison table) and [Set a Resource Manager workload identity service connection](https://learn.microsoft.com/en-us/azure/devops/pipelines/release/configure-workload-identity).
- GitHub, [aws/aws-toolkit-azure-devops#614](https://github.com/aws/aws-toolkit-azure-devops/issues/614).
