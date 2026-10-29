terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # thumbprint_list is optional from 5.81.0 (AWS validates the IdP
      # certificate chain against its trusted CA library).
      version = ">= 5.81"
    }
  }
}
