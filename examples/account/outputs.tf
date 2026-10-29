output "role_arns" {
  description = "Role ARNs to configure in the Azure DevOps service connections."
  value       = { for k, m in module.role : k => m.role_arn }
}
