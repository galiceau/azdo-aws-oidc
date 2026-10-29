# Architecture

Three views: the runtime flow, the multi-account deployment topology, and how AWS evaluates trust.

## 1. Runtime flow

```mermaid
flowchart LR
    subgraph ADO["Azure DevOps (organization)"]
        direction TB
        REPO[Repos] --> PIPE[Pipeline]
        PIPE --> TASK["AWS Toolkit task<br/>(awsCredentials: connection)"]
        SC["AWS service connection (OIDC)<br/>sub = sc://org/project/connection"]
        TASK -. uses .-> SC
        IDP[("OIDC token issuer")]
        SC -. requests a JWT .-> IDP
    end

    subgraph AWS["Target AWS account"]
        direction TB
        OIDC["IAM OIDC provider<br/>(issuer_url, audience)"]
        STS[AWS STS]
        ROLE["IAM Role<br/>trust: aud + sub"]
        POL[["IAM Policies<br/>(least privilege)"]]
        RES[(AWS resources)]
        OIDC <--> STS
        STS -->|temporary credentials| ROLE
        POL --> ROLE
        ROLE -->|API calls| RES
    end

    SC == "1. AssumeRoleWithWebIdentity(JWT, RoleArn)" ==> STS
    STS == "2. temporary credentials" ==> TASK
    TASK == "3. deployment" ==> RES
```

Key points: no secret stored in Azure DevOps; credentials expire (duration = `max_session_duration`); AWS only trusts the issuer registered in the provider.

## 2. Deployment topology (multi-account)

```mermaid
flowchart TB
    subgraph REPO["This repository (Terraform)"]
        MP[modules/oidc-provider]
        MR[modules/oidc-role]
        STACK["examples/account<br/>(1 stack, 1 tfvars per account)"]
        STACK --> MP
        STACK --> MR
    end

    subgraph PIPE["Infrastructure pipeline (matrix per account)"]
        J1[job account A]
        J2[job account B]
        J3[job account C]
    end

    STACK ==> PIPE

    subgraph BACKEND["S3 backend (state per account)"]
        S1[(oidc/A.tfstate)]
        S2[(oidc/B.tfstate)]
        S3[(oidc/C.tfstate)]
    end

    J1 --> S1
    J2 --> S2
    J3 --> S3

    subgraph A["Account A"]
        PA[OIDC provider] --- RA1[Role dev] & RA2[Role test]
    end
    subgraph B["Account B"]
        PB[OIDC provider] --- RB1[Role prod]
    end
    subgraph C["Account C"]
        PC[OIDC provider] --- RC1[Role dev]
    end

    J1 -- "deployer_role_arn" --> A
    J2 -- "deployer_role_arn" --> B
    J3 -- "deployer_role_arn" --> C
```

One provider per account, one role per environment. State and deployment credentials are isolated per account.

## 3. Trust evaluation

```mermaid
flowchart TD
    A[JWT received by STS] --> B{"iss = URL of a<br/>registered provider?"}
    B -- no --> X[Denied]
    B -- yes --> C{"Valid signature<br/>(issuer public keys)?"}
    C -- no --> X
    C -- yes --> D{"aud in provider<br/>client_id_list?"}
    D -- no --> X
    D -- yes --> E{"Role trust policy:<br/>host:aud = audience?"}
    E -- no --> X
    E -- yes --> F{"host:sub in subjects?<br/>(sc://org/project/connection)"}
    F -- no --> X
    F -- yes --> G[Temporary credentials<br/>issued]
```

`sub` is the only boundary between two connections of the same organization, hence the rule "one connection + one role per environment" and the guard rail rejecting a role without `sub` or with a bare `*` (see [design.md](design.md)).

## 4. Responsibilities

| Layer | Responsible for | Tool |
|---|---|---|
| Azure DevOps | Who can use the connection (authorized pipelines, approvals, branches) | Service connection + checks |
| Trust policy | Which connection can assume which role | `modules/oidc-role` (`aud`, `sub`) |
| Role policies | What the connection can do in the account | `managed_policy_arns`, `inline_policies` |
| IAM provider | Which issuer is recognized | `modules/oidc-provider` |
