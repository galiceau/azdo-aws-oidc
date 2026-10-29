# Dépannage

| Symptôme | Cause probable | Action |
|---|---|---|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | `sub` ou `aud` ne correspond pas à la trust policy | Comparer `terraform output` du rôle (`subjects`) au sujet affiché dans la service connection : casse, espaces, projet, nom de connexion. |
| `No OpenIDConnect provider found in your account` | Provider absent dans ce compte ou URL différente | Vérifier `issuer_url` (sans `/` final) et que la stack a été appliquée dans le bon compte. |
| `Invalid identity token` / erreur d'audience | `client_id_list` ne contient pas l'audience du jeton | Garder `api://AzureADTokenExchange`, ou l'audience affichée par la connexion. |
| Connexion marquée *deprecated* dans Azure DevOps | Issuer `vstoken.dev.azure.com` en cours de retrait | Voir [design.md §Risques](design.md#risques-et-points-ouverts) : ajouter le nouvel issuer et un rôle/`subjects` correspondant. |
| `terraform apply` : « Provide at least one service_connections… » | Rôle sans `sub` | Renseigner `service_connections` ou `subjects` (garde-fou volontaire). |
| Session trop courte | `max_session_duration` < durée du job | Augmenter `max_session_duration` (3600–43200 s). |

Vérification d'identité côté AWS (à lancer dans le bon compte) : `aws sts get-caller-identity`.
