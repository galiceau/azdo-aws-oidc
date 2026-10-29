# azdo-aws-oidc

Authenticate **Azure DevOps** pipelines to **AWS** with **OIDC** (workload identity federation), with no long-lived access keys.

- Two composable Terraform modules: `oidc-provider` (one per account) and `oidc-role` (one per service connection / environment).
- A per-account example stack, native tests (`terraform test`, no AWS access needed) and a consumer pipeline.
- Documentation: [architecture (diagrams)](docs/architecture.md), [design](docs/design.md), [Azure DevOps setup](docs/azure-devops-setup.md), [troubleshooting](docs/troubleshooting.md).

## How it works

```mermaid
sequenceDiagram
    participant P as Pipeline (Azure DevOps)
    participant SC as AWS service connection (OIDC)
    participant STS as AWS STS
    participant IAM as IAM Role
    P->>SC: uses the connection (awsCredentials)
    SC->>SC: issues a JWT (iss, aud, sub = sc://org/project/connection)
    SC->>STS: AssumeRoleWithWebIdentity(JWT, RoleArn)
    STS->>STS: verifies signature (IAM provider) + aud/sub conditions (trust policy)
    STS-->>P: temporary credentials
    P->>IAM: AWS API calls, limited by the role policies
```

## Quick start

```bash
cd examples/account
cp terraform.tfvars.example terraform.tfvars   # set issuer_url, org/project/connections
terraform init -backend-config=...             # one state per AWS account
terraform apply
terraform output role_arns                      # -> value for the service connection
```

Then create the service connection in Azure DevOps: [docs/azure-devops-setup.md](docs/azure-devops-setup.md).

## Modules

| Module | Purpose | Key inputs | Outputs |
|---|---|---|---|
| `modules/oidc-provider` | `aws_iam_openid_connect_provider` for the Azure DevOps issuer | `issuer_url`, `client_id_list` | `arn`, `host` |
| `modules/oidc-role` | IAM role + `aud`/`sub` trust policy + policies | `provider_arn`, `provider_host`, `service_connections`, `managed_policy_arns`, `inline_policies` | `role_arn`, `role_name`, `subjects` |

## Tests

```bash
for m in modules/oidc-provider modules/oidc-role; do (cd $m && terraform init -backend=false && terraform test); done
cd examples/account && terraform init -backend=false && terraform validate
```

## Warning: issuer being deprecated

Microsoft announces the retirement of the `https://vstoken.dev.azure.com/<guid>` issuer on **July 1, 2027** for *Azure Resource Manager* service connections; new ones use the Microsoft Entra issuer. The documentation I consulted does not confirm the exact impact on *AWS* service connections: see [design.md, Risks](docs/design.md#risks-and-open-points). The modules are issuer-agnostic (`issuer_url` + `subjects`) to absorb that change.
