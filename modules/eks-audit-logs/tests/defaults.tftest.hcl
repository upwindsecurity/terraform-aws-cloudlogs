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

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111111111111:role/mock-role"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      arn = "arn:aws:lambda:us-east-1:111111111111:function:mock-function"
    }
  }
}

mock_provider "random" {}

variables {
  upwind_organization_id           = "org_test"
  upwind_integration_client_id     = "test-client-id"
  upwind_integration_client_secret = "test-client-secret"
}

run "default_names_and_versions" {
  command = plan

  assert {
    condition     = aws_iam_role.execution.name == "us-east-1-UpwindReportLogsLambdaExecutionRole"
    error_message = "Execution role must default to the region-prefixed name"
  }

  assert {
    condition     = aws_iam_role_policy.cloudwatch_access.name == "us-east-1-AllowUpwindLambdaAccessCloudWatchPolicy"
    error_message = "CloudWatch policy must default to the region-prefixed name"
  }

  assert {
    condition     = aws_iam_role_policy.secret_access.name == "us-east-1-AllowUpwindLambdaAccessOwnSecretPolicy"
    error_message = "Secret policy must default to the region-prefixed name"
  }

  assert {
    condition     = aws_iam_role_policy.s3_access.name == "us-east-1-AllowUpwindLambdaAccessS3Policy"
    error_message = "S3 policy must default to the region-prefixed name"
  }

  assert {
    condition     = aws_lambda_function.this.function_name == "UpwindLogReporterLambda-us-east-1"
    error_message = "Lambda name must default to UpwindLogReporterLambda-<region>"
  }

  assert {
    condition     = aws_lambda_function.this.runtime == "python3.12"
    error_message = "Runtime must default to python3.12"
  }

  assert {
    condition     = aws_lambda_function.this.reserved_concurrent_executions == null
    error_message = "Concurrency must stay unreserved when lambda_reserved_concurrent_executions is unset"
  }

  assert {
    condition     = aws_lambda_function.this.s3_key == "log_reporter/${var.lambda_version}.zip"
    error_message = "S3 key must be derived from lambda_version"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["lambdaVersion"] == var.lambda_version
    error_message = "lambdaVersion env var must equal lambda_version"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["upwindTemplateVersion"] == var.lambda_version
    error_message = "upwindTemplateVersion env var must equal lambda_version"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["baseUrl"] == "https://integration.upwind.io"
    error_message = "Default upwind_region must resolve US endpoints"
  }

  assert {
    condition     = length(aws_secretsmanager_secret.upwind_api_credentials) == 1
    error_message = "Secret must be created when no BYO secret ARN is supplied"
  }

  assert {
    condition     = length(aws_secretsmanager_secret_version.upwind_api_credentials) == 1
    error_message = "Secret version must be created when no BYO secret ARN is supplied"
  }

  assert {
    condition     = aws_secretsmanager_secret.upwind_api_credentials[0].recovery_window_in_days == 30
    error_message = "Created secret must default to a 30-day recovery window"
  }
}

run "lambda_version_threads_everywhere" {
  command = plan

  variables {
    lambda_version = "9.9.9-sentinel"
  }

  assert {
    condition     = aws_lambda_function.this.s3_key == "log_reporter/9.9.9-sentinel.zip"
    error_message = "S3 key must be derived from lambda_version"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["lambdaVersion"] == "9.9.9-sentinel"
    error_message = "lambdaVersion env var must thread from lambda_version"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["upwindTemplateVersion"] == "9.9.9-sentinel"
    error_message = "upwindTemplateVersion env var must thread from lambda_version"
  }

  assert {
    condition     = aws_lambda_function.this.tags["upwind_lambda_log_reporter_version"] == "9.9.9-sentinel"
    error_message = "version tag must thread from lambda_version"
  }
}

run "registration_payload_carries_identity" {
  command = apply

  variables {
    lambda_version = "9.9.9-sentinel"
  }

  assert {
    condition     = jsondecode(aws_lambda_invocation.registration.input)["lambdaVersion"] == "9.9.9-sentinel"
    error_message = "Registration payload must carry lambda_version"
  }

  assert {
    # NOTE: the UUID portion is intentionally permissive (`.+`) rather than a strict
    # UUID pattern: terraform test's mock_provider "random" generates a short
    # placeholder string (not RFC 4122 UUID-shaped) for random_uuid.result during a
    # mock apply. The "terraform:TF-" prefix is still asserted strictly.
    condition     = can(regex("^terraform:TF-[^:]+:.+$", jsondecode(aws_lambda_invocation.registration.input)["StackId"]))
    error_message = "Registration payload StackId must be terraform:TF-<module version>:<deployment uuid>"
  }
}
