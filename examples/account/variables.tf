variable "region" {
  type        = string
  description = "AWS region used for the API calls (IAM is global)."
}

variable "deployer_role_arn" {
  type        = string
  description = "Role the pipeline assumes in the target account to run this stack (cross-account bootstrap). Empty = use ambient credentials."
  default     = ""
}

variable "issuer_url" {
  type        = string
  description = "Issuer URL copied from the Azure DevOps service connection."
}

variable "roles" {
  type = map(object({
    service_connections = list(object({
      organization = string
      project      = string
      name         = string
    }))
    managed_policy_arns  = optional(set(string), [])
    inline_policy_files  = optional(set(string), [])
    max_session_duration = optional(number, 3600)
  }))
  description = "One IAM role per entry. Key = role name."
}

variable "tags" {
  type    = map(string)
  default = {}
}
