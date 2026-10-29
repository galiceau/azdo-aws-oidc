# Azure DevOps setup

Procedure aligned with the official AWS walkthrough ([How to federate into AWS from Azure DevOps using OpenID Connect](https://aws.amazon.com/blogs/modernizing-with-aws/how-to-federate-into-aws-from-azure-devops-using-openid-connect/)).

Prerequisites:

- **AWS Toolkit for Azure DevOps 1.15.0 or later** installed in the organization.
- Rights to create service connections in the project, and to create IAM providers and roles in the AWS account.

## 1. Create the service connection first (the role does not need to exist yet)

The role name is chosen in the Terraform `roles` map, so its ARN is known in advance (`arn:aws:iam::<account-id>:role/<role name>`).

*Project settings → Pipelines → Service connections → New service connection → AWS*:

- **Role to assume**: the role ARN.
- **Role session name** (optional): defaults to `aws-vsts-tools`.
- Tick **Use OIDC**.
- **Service connection name**: the exact name; it becomes part of the `sub`.
- Do **not** tick "Grant access permission to all pipelines".

## 2. Read the issuer, audience and subject from a first run

The issuer contains the organization GUID, which is not shown in the connection form. Run a throwaway pipeline that uses the connection (see [`pipelines/azure-pipelines.example.yml`](../pipelines/azure-pipelines.example.yml)). It fails at this stage (no provider or role yet), but the task log contains a line starting with `OIDC Token generated` that shows:

| Value | Expected shape | Terraform input |
|---|---|---|
| Issuer | `https://vstoken.dev.azure.com/<organization-guid>` | `issuer_url` |
| Audience | `api://AzureADTokenExchange` | `client_id_list` / `audience` (defaults) |
| Subject | `sc://<organization>/<project>/<connection name>` | `service_connections` (or `subjects`) |

Authorize the pipeline to use the connection when Azure DevOps asks (*View → Permit*).

> If the issuer or the subject shown differs from the shapes above (for example an issuer starting with `https://login.microsoftonline.com/`), use the displayed values: set `issuer_url` accordingly and pass the subject through `subjects`. See [design.md, Risks](design.md#risks-and-open-points).

## 3. Apply the Terraform stack

Fill `issuer_url` and the `roles` map in `terraform.tfvars`, then `terraform apply` in each target account. `terraform output role_arns` must match the ARN used in step 1.

## 4. Secure the connection

- Authorize each pipeline explicitly.
- Add *Approvals and checks* (approval, branch restriction) on production connections.
- One connection (and one role) per environment.

## 5. Session duration

The task requests credentials for the duration set by the pipeline variable `aws.rolecredential.maxduration` (900–43200 seconds). The role must allow at least that long: set `max_session_duration` (3600–43200) on the role accordingly.

## 6. Verify

Re-run the pipeline. `aws sts get-caller-identity` must return `…assumed-role/<role name>/…`.

## Using it with other tools (Terraform, etc.)

`AWSShellScript@1` exposes the temporary credentials to any tool in the script (Terraform, kubectl, SDKs), as shown in the official walkthrough; see the example pipeline.
