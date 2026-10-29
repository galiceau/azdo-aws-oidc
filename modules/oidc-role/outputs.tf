output "role_arn" {
  description = "Role ARN to paste in the Azure DevOps AWS service connection."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name."
  value       = aws_iam_role.this.name
}

output "subjects" {
  description = "Subjects trusted by the role."
  value       = local.subjects
}
