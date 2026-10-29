# Architecture

Trois vues : le flux d'exécution, la topologie de déploiement multi-comptes, et l'évaluation de la confiance côté AWS.

## 1. Flux d'exécution (runtime)

```mermaid
flowchart LR
    subgraph ADO["Azure DevOps (organisation)"]
        direction TB
        REPO[Repos] --> PIPE[Pipeline]
        PIPE --> TASK["Tâche AWS Toolkit<br/>(awsCredentials: connexion)"]
        SC["Service connection AWS (OIDC)<br/>sub = sc://org/projet/connexion"]
        TASK -. utilise .-> SC
        IDP[("Émetteur de jetons<br/>OIDC (issuer)")]
        SC -. demande un JWT .-> IDP
    end

    subgraph AWS["Compte AWS cible"]
        direction TB
        OIDC["IAM OIDC provider<br/>(issuer_url, audience)"]
        STS[AWS STS]
        ROLE["IAM Role<br/>trust: aud + sub"]
        POL[["IAM Policies<br/>(moindre privilège)"]]
        RES[(Ressources AWS)]
        OIDC <--> STS
        STS -->|credentials temporaires| ROLE
        POL --> ROLE
        ROLE -->|appels API| RES
    end

    SC == "1. AssumeRoleWithWebIdentity(JWT, RoleArn)" ==> STS
    STS == "2. credentials temporaires" ==> TASK
    TASK == "3. déploiement" ==> RES
```

Points clés : aucun secret stocké dans Azure DevOps ; les credentials expirent (durée = `max_session_duration`) ; AWS ne fait confiance qu'à l'issuer enregistré dans le provider.

## 2. Topologie de déploiement (multi-comptes)

```mermaid
flowchart TB
    subgraph REPO["Ce dépôt (Terraform)"]
        MP[modules/oidc-provider]
        MR[modules/oidc-role]
        STACK["examples/account<br/>(1 stack, 1 tfvars par compte)"]
        STACK --> MP
        STACK --> MR
    end

    subgraph PIPE["Pipeline d'infrastructure (matrice par compte)"]
        J1[job compte A]
        J2[job compte B]
        J3[job compte C]
    end

    STACK ==> PIPE

    subgraph BACKEND["Backend S3 (state par compte)"]
        S1[(oidc/A.tfstate)]
        S2[(oidc/B.tfstate)]
        S3[(oidc/C.tfstate)]
    end

    J1 --> S1
    J2 --> S2
    J3 --> S3

    subgraph A["Compte A"]
        PA[OIDC provider] --- RA1[Role dev] & RA2[Role inte]
    end
    subgraph B["Compte B"]
        PB[OIDC provider] --- RB1[Role prod]
    end
    subgraph C["Compte C"]
        PC[OIDC provider] --- RC1[Role dev]
    end

    J1 -- "deployer_role_arn" --> A
    J2 -- "deployer_role_arn" --> B
    J3 -- "deployer_role_arn" --> C
```

Un provider par compte, un rôle par environnement. Le state et les credentials de déploiement sont isolés par compte.

## 3. Évaluation de la confiance (trust policy)

```mermaid
flowchart TD
    A[JWT reçu par STS] --> B{"iss = URL d'un<br/>provider enregistré ?"}
    B -- non --> X[Refusé]
    B -- oui --> C{"Signature valide<br/>(clés publiques de l issuer) ?"}
    C -- non --> X
    C -- oui --> D{"aud ∈ client_id_list<br/>du provider ?"}
    D -- non --> X
    D -- oui --> E{"Trust policy du rôle :<br/>host:aud = audience ?"}
    E -- non --> X
    E -- oui --> F{"host:sub ∈ subjects ?<br/>(sc://org/projet/connexion)"}
    F -- non --> X
    F -- oui --> G[Credentials temporaires<br/>délivrés]
```

Le `sub` est la seule frontière entre deux connexions d'une même organisation : d'où la règle « une connexion + un rôle par environnement » et le garde-fou refusant un rôle sans `sub` ou avec `*` seul (voir [design.md](design.md)).

## 4. Responsabilités

| Couche | Responsable de | Outil |
|---|---|---|
| Azure DevOps | Qui peut utiliser la connexion (pipelines autorisés, approvals, branches) | Service connection + checks |
| Trust policy | Quelle connexion peut assumer quel rôle | `modules/oidc-role` (`aud`, `sub`) |
| Policies du rôle | Ce que la connexion peut faire dans le compte | `managed_policy_arns`, `inline_policies` |
| Provider IAM | Quel émetteur est reconnu | `modules/oidc-provider` |
