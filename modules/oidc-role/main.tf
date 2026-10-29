locals {
  subjects = concat(
    [for sc in var.service_connections : "sc://${sc.organization}/${sc.project}/${sc.name}"],
    var.subjects,
  )
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.provider_host}:aud"
      values   = [var.audience]
    }

    condition {
      test     = var.subject_match
      variable = "${var.provider_host}:sub"
      values   = local.subjects
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.name
  path                 = var.path
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.max_session_duration
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags

  lifecycle {
    precondition {
      condition     = length(local.subjects) > 0
      error_message = "Provide at least one service_connections or subjects entry: a role without `sub` condition would trust the whole issuer."
    }
    precondition {
      condition     = !contains(local.subjects, "*")
      error_message = "A bare '*' subject is forbidden: it would trust every service connection of the issuer."
    }
  }
}

# for_each on static keys (not count): adding/removing a policy never shifts the others.
resource "aws_iam_policy" "inline" {
  for_each = var.inline_policies

  name   = "${var.name}-${each.key}"
  policy = each.value
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "inline" {
  for_each = aws_iam_policy.inline

  role       = aws_iam_role.this.name
  policy_arn = each.value.arn
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = var.managed_policy_arns

  role       = aws_iam_role.this.name
  policy_arn = each.value
}
