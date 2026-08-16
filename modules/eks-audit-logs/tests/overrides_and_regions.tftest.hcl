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
}

run "supplied_names_win" {
  command = plan

  variables {
    lambda_execution_role_name = "my-custom-role"
    lambda_name                = "my-custom-lambda"
    cloudwatch_policy_name     = "my-cw-policy"
    secret_policy_name         = "my-secret-policy"
    s3_policy_name             = "my-s3-policy"
  }

  assert {
    condition     = aws_iam_role.execution.name == "my-custom-role"
    error_message = "A supplied role name must be used verbatim"
  }

  assert {
    condition     = aws_lambda_function.this.function_name == "my-custom-lambda"
    error_message = "A supplied lambda name must be used verbatim"
  }

  assert {
    condition     = aws_iam_role_policy.cloudwatch_access.name == "my-cw-policy"
    error_message = "A supplied policy name must be used verbatim"
  }

  assert {
    condition     = aws_iam_role_policy.secret_access.name == "my-secret-policy"
    error_message = "A supplied secret policy name must be used verbatim"
  }

  assert {
    condition     = aws_iam_role_policy.s3_access.name == "my-s3-policy"
    error_message = "A supplied s3 policy name must be used verbatim"
  }
}

run "reserved_concurrency_threads_to_lambda" {
  command = plan

  variables {
    lambda_reserved_concurrent_executions = 5
  }

  assert {
    condition     = aws_lambda_function.this.reserved_concurrent_executions == 5
    error_message = "A supplied concurrency reservation must be set on the lambda"
  }
}

run "reserved_concurrency_zero_throttles" {
  command = plan

  variables {
    lambda_reserved_concurrent_executions = 0
  }

  assert {
    condition     = aws_lambda_function.this.reserved_concurrent_executions == 0
    error_message = "A zero reservation (throttle) must be set on the lambda verbatim"
  }
}

run "reserved_concurrency_rejects_negative" {
  command = plan

  variables {
    lambda_reserved_concurrent_executions = -1
  }

  expect_failures = [
    var.lambda_reserved_concurrent_executions,
  ]
}

run "eu_region_endpoints" {
  command = plan

  variables {
    upwind_region = "eu"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["baseUrl"] == "https://integration.eu.upwind.io"
    error_message = "eu region must resolve EU base URL"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["authUrl"] == "https://auth.eu.upwind.io/oauth/token"
    error_message = "eu region must resolve EU auth URL"
  }
}

run "ap_region_endpoints" {
  command = plan

  variables {
    upwind_region = "ap"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["baseUrl"] == "https://integration.ap.upwind.io"
    error_message = "ap region must resolve AP base URL"
  }
}

run "me_region_endpoints" {
  command = plan

  variables {
    upwind_region = "me"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["baseUrl"] == "https://integration.me.upwind.io"
    error_message = "me region must resolve ME base URL"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["authUrl"] == "https://auth.me.upwind.io/oauth/token"
    error_message = "me region must resolve ME auth URL"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["authAudience"] == "https://integration.me.upwind.io"
    error_message = "me region must resolve ME auth audience"
  }
}
