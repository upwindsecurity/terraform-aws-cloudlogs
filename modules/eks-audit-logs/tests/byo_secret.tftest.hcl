mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      id     = "us-east-1"
      name   = "us-east-1"
      region = "us-east-1"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111111111111"
    }
  }
  mock_data "aws_eks_clusters" {
    defaults = {
      names = ["demo-cluster"]
    }
  }
  mock_data "aws_eks_cluster" {
    defaults = {
      enabled_cluster_log_types = ["audit"]
    }
  }
}

mock_provider "random" {}

variables {
  upwind_organization_id        = "org_test"
  upwind_credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:111111111111:secret:customer-creds-Ab12Cd"
}

run "no_secret_created_when_byo" {
  command = plan

  assert {
    condition     = length(aws_secretsmanager_secret.upwind_api_credentials) == 0
    error_message = "No secret may be created when a BYO secret ARN is supplied"
  }

  assert {
    condition     = length(aws_secretsmanager_secret_version.upwind_api_credentials) == 0
    error_message = "No secret version may be created when a BYO secret ARN is supplied"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["upwindCredentialsSecretArn"] == var.upwind_credentials_secret_arn
    error_message = "Lambda must be pointed at the BYO secret"
  }
}

run "byo_secret_policy_carries_arn_wildcard" {
  command = plan

  assert {
    # A customer-supplied ARN may lack the random 6-char suffix AWS appends,
    # so the policy must grant on "<arn>*" (CFN template parity).
    condition     = jsondecode(aws_iam_role_policy.secret_access.policy).Statement[0].Resource == "${var.upwind_credentials_secret_arn}*"
    error_message = "Secret policy must target the BYO ARN with a trailing wildcard"
  }
}

run "missing_credentials_are_rejected" {
  command = plan

  variables {
    upwind_credentials_secret_arn = null
  }

  expect_failures = [terraform_data.credentials_validator]
}
