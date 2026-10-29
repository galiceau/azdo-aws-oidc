variable "issuer_url" {
  type        = string
  description = <<-EOT
    Issuer URL of the Azure DevOps token, with or without the https:// prefix.
    - Azure DevOps issuer (legacy): https://vstoken.dev.azure.com/<organization-guid>
    - Microsoft Entra issuer:       https://login.microsoftonline.com/<tenant-id>/v2.0
    Copy the exact value shown in the service connection (see docs/azure-devops-setup.md).
  EOT

  validation {
    condition     = can(regex("^(https://)?[a-z0-9.-]+/.+", var.issuer_url)) && !endswith(var.issuer_url, "/")
    error_message = "issuer_url must be a host + path (e.g. vstoken.dev.azure.com/<guid>) without trailing slash."
  }
}

variable "client_id_list" {
  type        = list(string)
  description = "Audiences accepted by the provider. Azure DevOps service connections use api://AzureADTokenExchange."
  default     = ["api://AzureADTokenExchange"]

  validation {
    condition     = length(var.client_id_list) > 0
    error_message = "At least one audience is required."
  }
}

variable "thumbprint_list" {
  type        = list(string)
  description = "Optional. Leave empty: AWS validates the certificate chain with its own trusted CA library."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the provider."
  default     = {}
}
