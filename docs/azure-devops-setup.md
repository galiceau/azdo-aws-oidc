# Azure DevOps setup

Prerequisites: the **AWS Toolkit for Azure DevOps** extension installed in the organization, and the IAM role already created (`terraform output role_arns`).

## 1. Get the issuer and subject

In the project: *Project settings → Pipelines → Service connections → New service connection → AWS*, choose **OIDC / workload identity federation** authentication and fill in:

- **Role to assume**: the role ARN (`role_arns`).
- **Service connection name**: the exact name; it becomes part of the `sub`.

Note the **issuer** and the **subject identifier** displayed (use "Keep as draft" if offered). These are the reference values for:

- `issuer_url` of the `oidc-provider` module;
- `sc://<organization>/<project>/<name>` for `service_connections` (or `subjects` if the format differs).

> Practical order: draft connection → note issuer/subject → `terraform apply` → finish and verify the connection.

## 2. Secure the connection

- Do **not** tick "Grant access permission to all pipelines": authorize each pipeline explicitly.
- Add *Approvals and checks* (approval, branch restriction) on production connections.
- One connection (and one role) per environment.

## 3. Use the connection

See [`pipelines/azure-pipelines.example.yml`](../pipelines/azure-pipelines.example.yml) (`AWSShellScript@1`, `AWSCLI@1` with `awsCredentials: <connection name>`). No secret in the pipeline.

## 4. Verify

Run the task `aws sts get-caller-identity`: the returned ARN must be `…assumed-role/<role name>/…`.
