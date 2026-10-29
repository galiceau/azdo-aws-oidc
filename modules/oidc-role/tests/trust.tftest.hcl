mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
}

variables {
  name          = "azdo-test"
  provider_arn  = "arn:aws:iam::111111111111:oidc-provider/vstoken.dev.azure.com/00000000-0000-0000-0000-000000000000"
  provider_host = "vstoken.dev.azure.com/00000000-0000-0000-0000-000000000000"
}

run "subject_is_built_from_service_connection" {
  command = plan
  variables {
    service_connections = [{ organization = "org", project = "proj", name = "sc1" }]
  }
  assert {
    condition     = output.subjects[0] == "sc://org/proj/sc1" && length(output.subjects) == 1
    error_message = "sub must be sc://<org>/<project>/<name>"
  }
}

run "role_without_subject_is_refused" {
  command         = plan
  expect_failures = [aws_iam_role.this]
}

run "bare_wildcard_is_refused" {
  command = plan
  variables {
    subjects = ["*"]
  }
  expect_failures = [aws_iam_role.this]
}

run "invalid_subject_match_is_refused" {
  command = plan
  variables {
    subjects      = ["sc://org/proj/sc1"]
    subject_match = "StringNotEquals"
  }
  expect_failures = [var.subject_match]
}
