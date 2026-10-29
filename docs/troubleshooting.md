# Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | `sub` or `aud` does not match the trust policy | Compare the role's `subjects` output with the subject shown in the service connection: case, spaces, project, connection name. |
| `No OpenIDConnect provider found in your account` | Provider missing in this account or different URL | Check `issuer_url` (no trailing `/`) and that the stack was applied in the right account. |
| `Invalid identity token` / audience error | `client_id_list` does not contain the token audience | Keep `api://AzureADTokenExchange`, or the audience displayed by the connection. |
| Connection flagged *deprecated* in Azure DevOps | `vstoken.dev.azure.com` issuer being retired | See [design.md, Risks](design.md#risks-and-open-points): add the new issuer and a matching role/`subjects`. |
| `terraform apply`: "Provide at least one service_connections…" | Role without `sub` | Set `service_connections` or `subjects` (intentional guard rail). |
| Session too short | `max_session_duration` shorter than the job | Increase `max_session_duration` (3600–43200 s). |

Identity check on the AWS side (run it in the right account): `aws sts get-caller-identity`.
