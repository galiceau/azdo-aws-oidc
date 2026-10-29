terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.81"
    }
  }
  # Configure the backend per account in the pipeline, e.g.:
  #   terraform init -backend-config="key=oidc/${ACCOUNT_ID}.tfstate" ...
  backend "s3" {}
}
