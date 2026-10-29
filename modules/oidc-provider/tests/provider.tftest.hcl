mock_provider "aws" {}

run "scheme_is_added_and_host_exposed" {
  command = plan
  variables {
    issuer_url = "vstoken.dev.azure.com/00000000-0000-0000-0000-000000000000"
  }
  assert {
    condition     = aws_iam_openid_connect_provider.this.url == "https://vstoken.dev.azure.com/00000000-0000-0000-0000-000000000000"
    error_message = "https:// must be prepended"
  }
}

run "trailing_slash_is_refused" {
  command = plan
  variables {
    issuer_url = "https://vstoken.dev.azure.com/abc/"
  }
  expect_failures = [var.issuer_url]
}
