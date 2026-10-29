output "arn" {
  description = "ARN of the OIDC provider (Principal.Federated in role trust policies)."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "host" {
  description = "Issuer without scheme: prefix of the IAM condition keys (<host>:aud, <host>:sub)."
  value       = trimprefix(aws_iam_openid_connect_provider.this.url, "https://")
}
