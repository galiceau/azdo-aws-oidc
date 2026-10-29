# Configuration côté Azure DevOps

Prérequis : l'extension **AWS Toolkit for Azure DevOps** installée dans l'organisation, et le rôle IAM déjà créé (`terraform output role_arns`).

## 1. Récupérer issuer et sujet

Dans le projet : *Project settings → Pipelines → Service connections → New service connection → AWS*, choisir l'authentification par **OIDC / workload identity federation** et renseigner :

- **Role to assume** : l'ARN du rôle (`role_arns`).
- **Service connection name** : le nom exact ; il entre dans le `sub`.

Relever l'**issuer** et le **subject identifier** affichés (brouillon / « Keep as draft » si proposé). Ce sont les valeurs de référence :

- `issuer_url` du module `oidc-provider` ;
- `sc://<organisation>/<projet>/<nom>` pour `service_connections` (ou `subjects` si le format diffère).

> L'ordre pratique : brouillon de connexion → relever issuer/sujet → `terraform apply` → finaliser et vérifier la connexion.

## 2. Sécuriser la connexion

- Ne **pas** cocher « Grant access permission to all pipelines » : autoriser chaque pipeline explicitement.
- Ajouter des *Approvals and checks* (approbation, restriction de branche) sur les connexions de production.
- Une connexion (et un rôle) par environnement.

## 3. Utiliser la connexion

Voir [`pipelines/azure-pipelines.example.yml`](../pipelines/azure-pipelines.example.yml) (`AWSShellScript@1`, `AWSCLI@1` avec `awsCredentials: <nom de la connexion>`). Aucun secret dans le pipeline.

## 4. Vérifier

Exécuter la tâche `aws sts get-caller-identity` : l'ARN retourné doit être `…assumed-role/<nom du rôle>/…`.
