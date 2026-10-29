locals {
  # Normalise: the AWS API wants the https:// form, while IAM condition keys
  # use the bare host/path (see outputs.tf -> provider_host).
  issuer_url = startswith(var.issuer_url, "https://") ? var.issuer_url : "https://${var.issuer_url}"
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = local.issuer_url
  client_id_list  = var.client_id_list
  thumbprint_list = length(var.thumbprint_list) > 0 ? var.thumbprint_list : null
  tags            = var.tags
}
