# Design

## Objectif

Donner à des pipelines Azure DevOps un accès AWS **temporaire, sans secret stocké**, avec un périmètre limité par environnement.

## Architecture

```
Azure DevOps                                   Compte AWS cible
┌───────────────────────────┐                 ┌──────────────────────────────────┐
│ Pipeline                  │                 │ IAM OIDC provider (issuer_url)   │
│  └─ task AWS Toolkit      │  1. JWT         │        │ valide la signature     │
│      └─ Service connection├────────────────►│ STS AssumeRoleWithWebIdentity    │
│         AWS (OIDC)        │                 │        │ trust policy: aud + sub │
│  sub = sc://org/proj/name │  2. creds temp  │ IAM Role (policies moindre priv.)│
│                           │◄────────────────┤                                  │
└───────────────────────────┘  3. appels API  └──────────────────────────────────┘
```

Une fois par compte : 1 provider. Par environnement : 1 rôle lié à 1 service connection (ou quelques-unes).

## Contrat de confiance

| Claim | Valeur | Contrôlé par |
|---|---|---|
| `iss` | URL de l'issuer (cf. `issuer_url`) | le provider IAM (URL du provider) |
| `aud` | `api://AzureADTokenExchange` | condition `StringEquals <host>:aud` |
| `sub` | `sc://<organisation>/<projet>/<service connection>` | condition `StringEquals <host>:sub` |

Conséquences à connaître :

- Le `sub` identifie la **service connection**, pas le pipeline ni la branche (contrairement à GitHub Actions). AWS ne peut donc pas distinguer deux pipelines utilisant la même connexion. La séparation fine se fait **côté Azure DevOps** : autorisation par pipeline, approvals et checks sur la connexion, branche protégée.
- Règle retenue : **une service connection et un rôle par environnement** (dev / inte / prod), jamais une connexion partagée entre prod et non-prod.
- `sub` est sensible à la casse et doit correspondre exactement (espaces compris dans les noms de projet).

## Décisions

| # | Décision | Raison |
|---|---|---|
| D1 | Séparer `oidc-provider` et `oidc-role` | Un compte ne peut avoir qu'un provider par URL ; plusieurs rôles doivent le partager. Un module unique « provider + rôle » empêche d'avoir deux rôles dans un même compte (le second provider échouerait : URL déjà enregistrée). |
| D2 | `aws_iam_policy_document` pour la trust policy | Fonction native du provider AWS, plutôt qu'un JSON assemblé à la main. |
| D3 | `Principal.Federated` = ARN du provider (output) | Évite de reconstruire l'ARN depuis l'ID de compte et l'URL. |
| D4 | `for_each` sur clés statiques pour policies et attachements | Avec `count`, retirer une policy décale les index et recrée les autres. |
| D5 | Pas de thumbprint par défaut | AWS valide la chaîne de certificats avec ses CA de confiance ; provider AWS ≥ 5.81 le rend optionnel. Plus de `ignore_changes` nécessaire. |
| D6 | Preconditions : au moins un `sub`, jamais `*` seul | Un rôle sans condition `sub` ferait confiance à toutes les connexions de l'organisation. |
| D7 | Pas de générateur de code | Générer du HCL par script (parsing de tfvars) pour contourner l'impossibilité de `for_each` sur les providers est fragile. Ici : **une stack par compte** (state et credentials distincts), pilotée par une matrice de pipeline. Pas de parsing maison. |
| D8 | Tests `terraform test` + `mock_provider` | Validation de la logique (sub, garde-fous) sans identifiants AWS. |
| D9 | Permissions : pas de `AdministratorAccess` par défaut | Le moindre privilège est un choix explicite de l'appelant ; l'exemple combine une policy managée et un `Deny` ciblé. |

## Déploiement multi-comptes

Terraform ne permet pas de `for_each` sur les providers. Option retenue : la même stack `examples/account` est exécutée **une fois par compte** :

- backend S3 avec une clé de state par compte (`-backend-config="key=oidc/<account_id>.tfstate"`) ;
- `deployer_role_arn` : rôle d'amorçage assumé dans le compte cible (ou credentials ambiants déjà dans le bon compte) ;
- une matrice de jobs Azure DevOps (`strategy.matrix`) itère sur les comptes avec un fichier `*.tfvars` par compte.

Alternative à évaluer si le nombre de comptes grandit : Terraform Stacks (`for_each` sur des déploiements/providers).

## Risques et points ouverts

1. **Dépréciation de l'issuer `vstoken.dev.azure.com`** (retrait annoncé le 1er juillet 2027, source Microsoft Learn *Configure workload identity*). La page vise explicitement les connexions *Azure Resource Manager* ; je n'ai pas trouvé de confirmation couvrant les connexions **AWS**. À vérifier avant d'industrialiser : créer une service connection AWS de test et lire l'issuer et le sujet affichés. Les modules acceptent un autre issuer (`issuer_url`) et des sujets bruts (`subjects`) ; il faudra alors un provider supplémentaire (ou le remplacement de l'ancien) et des rôles dont le `sub` suit le nouveau format.
2. **Création des service connections** : l'enregistrement de la connexion AWS en mode OIDC se fait dans Azure DevOps (UI ou API). Je n'ai pas vérifié si le provider Terraform `azuredevops` expose ce mode ; le guide décrit donc la procédure manuelle.
3. **Rôle d'amorçage** : le déploiement initial nécessite des droits IAM dans le compte (rôle de déploiement, SSO, ou agent managé). Hors du périmètre de ce dépôt.

## Sources

- Documentation Microsoft Learn, *Set a Resource Manager workload identity service connection* (dépréciation de l'issuer).
- Blog AWS DevOps, *Use OpenID Connect with AWS Toolkit for Azure DevOps* (trust policy `aud`/`sub`, OIDC + toolkit).
- Blog AWS Modernizing, *How to federate into AWS from Azure DevOps using OpenID Connect*.
