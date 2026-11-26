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
  upwind_organization_id           = "org_test"
  upwind_integration_client_id     = "test-client-id"
  upwind_integration_client_secret = "test-client-secret"
  create_lambda_execution_role     = false
  lambda_execution_role_arn        = "arn:aws:iam::111111111111:role/customer/UpwindLogReporter"
}

run "no_iam_created_when_byo_role" {
  command = plan

  assert {
    condition     = length(aws_iam_role.execution) == 0
    error_message = "No IAM role may be created when a BYO role ARN is supplied"
  }

  assert {
    condition = (
      length(aws_iam_role_policy.cloudwatch_access) == 0 &&
      length(aws_iam_role_policy.secret_access) == 0 &&
      length(aws_iam_role_policy.s3_access) == 0
    )
    error_message = "No IAM policy may be created when a BYO role ARN is supplied"
  }

  assert {
    condition     = aws_lambda_function.this.role == var.lambda_execution_role_arn
    error_message = "Lambda must run as the BYO role"
  }

  assert {
    condition     = output.lambda_execution_role_arn == var.lambda_execution_role_arn
    error_message = "Output must expose the BYO role ARN"
  }
}

run "govcloud_role_arn_is_accepted" {
  command = plan

  variables {
    lambda_execution_role_arn = "arn:aws-us-gov:iam::111111111111:role/UpwindLogReporter"
  }

  assert {
    condition     = aws_lambda_function.this.role == var.lambda_execution_role_arn
    error_message = "A partition-qualified role ARN must be accepted"
  }
}

run "non_role_arn_is_rejected" {
  command = plan

  variables {
    lambda_execution_role_arn = "arn:aws:iam::111111111111:user/someone"
  }

  expect_failures = [var.lambda_execution_role_arn]
}

run "role_name_instead_of_arn_is_rejected" {
  command = plan

  variables {
    lambda_execution_role_arn = "UpwindLogReporter"
  }

  expect_failures = [var.lambda_execution_role_arn]
}

run "role_arn_is_ignored_while_creating_the_role" {
  command = plan

  variables {
    create_lambda_execution_role = true
  }

  assert {
    condition     = length(aws_iam_role.execution) == 1
    error_message = "The module must create its role while create_lambda_execution_role is true"
  }
}

run "disabling_create_requires_role_arn" {
  command = plan

  variables {
    lambda_execution_role_arn = null
  }

  expect_failures = [var.create_lambda_execution_role]
}

run "role_and_policy_names_are_rejected_with_byo_role" {
  command = plan

  variables {
    lambda_execution_role_name = "my-custom-role"
  }

  expect_failures = [var.create_lambda_execution_role]
}
