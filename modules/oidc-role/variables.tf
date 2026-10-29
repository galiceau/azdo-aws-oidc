variable "name" {
  type        = string
  description = "IAM role name (this is the Role ARN suffix configured in the Azure DevOps service connection)."
}

variable "path" {
  type        = string
  description = "IAM path of the role."
  default     = "/"
}

variable "provider_arn" {
  type        = string
  description = "ARN of the Azure DevOps OIDC provider (output `arn` of ../oidc-provider)."
}

variable "provider_host" {
  type        = string
  description = "Issuer host/path without scheme (output `host` of ../oidc-provider)."
}

variable "audience" {
  type        = string
  description = "Expected `aud` claim."
  default     = "api://AzureADTokenExchange"
}

variable "service_connections" {
  type = list(object({
    organization = string
    project      = string
    name         = string
  }))
  description = <<-EOT
    Azure DevOps service connections allowed to assume the role. Each one is
    translated into the subject `sc://<organization>/<project>/<name>`
    (Azure DevOps issuer). Names are case sensitive and must match exactly.
  EOT
  default     = []
}

variable "subjects" {
  type        = list(string)
  description = "Raw `sub` values, for issuers/formats not covered by service_connections (e.g. Entra issuer). Concatenated with service_connections."
  default     = []
}

variable "subject_match" {
  type        = string
  description = "StringEquals (recommended) or StringLike (only if you really need wildcards in subjects)."
  default     = "StringEquals"

  validation {
    condition     = contains(["StringEquals", "StringLike"], var.subject_match)
    error_message = "subject_match must be StringEquals or StringLike."
  }
}

variable "managed_policy_arns" {
  type        = set(string)
  description = "AWS/customer managed policy ARNs attached to the role. Prefer least-privilege policies over AdministratorAccess."
  default     = []
}

variable "inline_policies" {
  type        = map(string)
  description = "Custom IAM policies: map of <short name> => <policy JSON>. Created as managed policies named <name>-<key> and attached."
  default     = {}
}

variable "permissions_boundary_arn" {
  type        = string
  description = "Optional permissions boundary."
  default     = null
}

variable "max_session_duration" {
  type        = number
  description = "Max session duration in seconds (3600-43200). Must cover the longest pipeline job that uses the role."
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the role and policies."
  default     = {}
}
