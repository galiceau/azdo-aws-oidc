provider "aws" {
  region = var.region

  dynamic "assume_role" {
    for_each = var.deployer_role_arn == "" ? [] : [var.deployer_role_arn]
    content {
      role_arn = assume_role.value
    }
  }
}

# One provider per account and issuer.
module "provider" {
  source     = "../../modules/oidc-provider"
  issuer_url = var.issuer_url
  tags       = var.tags
}

# One role per service connection group (typically one per environment).
module "role" {
  source   = "../../modules/oidc-role"
  for_each = var.roles

  name                = each.key
  provider_arn        = module.provider.arn
  provider_host       = module.provider.host
  service_connections = each.value.service_connections
  managed_policy_arns = each.value.managed_policy_arns
  inline_policies = {
    for f in each.value.inline_policy_files : trimsuffix(basename(f), ".json") => file("${path.module}/policies/${f}")
  }
  max_session_duration = each.value.max_session_duration
  tags                 = var.tags
}
