"""Generates docs/images/architecture.png (requires: pip install diagrams, graphviz).

Run from the repository root:  python3 docs/images/architecture.py
"""
from diagrams import Cluster, Diagram, Edge
from diagrams.aws.general import General
from diagrams.aws.security import IAM, IAMAWSSts, IAMPermissions, IAMRole
from diagrams.aws.storage import S3
from diagrams.azure.devops import AzureDevops, Pipelines, Repos
from diagrams.onprem.iac import Terraform

graph_attr = {"fontsize": "22", "labelloc": "t", "pad": "0.4", "nodesep": "0.7", "ranksep": "1.0", "splines": "spline", "newrank": "true"}
node_attr = {"fontsize": "13"}
edge_attr = {"fontsize": "12"}

with Diagram(
    "Azure DevOps to AWS: OIDC federation (no stored secret)",
    filename="docs/images/architecture",
    outformat="png",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
    node_attr=node_attr,
    edge_attr=edge_attr,
):
    tf = Terraform("modules in this repo")

    with Cluster("Azure DevOps organization"):
        repos = Repos("Repos")
        pipe = Pipelines("Pipeline")
        sc = AzureDevops("AWS service connection\n(OIDC)\nsub = sc://org/project/name")
        repos >> pipe >> sc

    with Cluster("Target AWS account"):
        idp = IAM("IAM OIDC provider\n(issuer + audience)")
        sts = IAMAWSSts("AWS STS")
        role = IAMRole("IAM role\ntrust: aud + sub")
        pol = IAMPermissions("IAM policies\n(least privilege)")
        res = S3("AWS resources")
        idp - Edge(style="dotted", dir="both") - sts
        sts >> Edge(label="3. temporary credentials  ", color="darkgreen") >> role
        pol >> role
        role >> Edge(label="5. API calls  ", color="darkgreen") >> res

    sc >> Edge(label="1. JWT  ", color="darkorange", penwidth="2") >> idp
    sc >> Edge(label="2. AssumeRoleWith-\nWebIdentity  ", color="darkorange", penwidth="2") >> sts
    sc >> Edge(label="4. credentials  ", color="darkgreen", style="dashed") >> pipe
    tf >> Edge(label="provisions  ", style="dashed", color="gray") >> idp
    tf >> Edge(style="dashed", color="gray") >> role
