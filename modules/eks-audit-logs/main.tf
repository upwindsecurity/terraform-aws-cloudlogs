data "aws_eks_clusters" "all" {}

data "aws_eks_cluster" "this" {
  for_each = length(var.cluster_names) > 0 ? toset(var.cluster_names) : toset(data.aws_eks_clusters.all.names)
  name     = each.value
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "random_uuid" "deployment" {}

resource "terraform_data" "credentials_validator" {
  lifecycle {
    precondition {
      condition     = var.upwind_credentials_secret_arn != null || (var.upwind_integration_client_id != null && var.upwind_integration_client_secret != null)
      error_message = "Either upwind_credentials_secret_arn, or both upwind_integration_client_id and upwind_integration_client_secret, must be set."
    }
  }
}

resource "aws_iam_role" "execution" {
  name = local.execution_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["lambda.amazonaws.com"]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudwatch_access" {
  name = local.cloudwatch_policy_name
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.lambda.arn}:*",
          "${aws_cloudwatch_log_group.lambda.arn}:log-stream/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "secret_access" {
  name = local.secret_policy_name
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:GetSecretValue"
        ]
        # Created secrets carry AWS's random 6-char ARN suffix already; a
        # customer-supplied ARN may lack it, hence the trailing wildcard.
        Resource = local.is_secret_created ? aws_secretsmanager_secret.upwind_api_credentials[0].arn : "${var.upwind_credentials_secret_arn}*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_access" {
  name = local.s3_policy_name
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${local.lambda_s3_bucket}",
          "arn:aws:s3:::${local.lambda_s3_bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_lambda_function" "this" {
  function_name = local.lambda_name
  role          = aws_iam_role.execution.arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  architectures = ["arm64"]
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_s3_key
  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout

  environment {
    variables = {
      authAudience               = local.endpoints.auth_audience
      authUrl                    = local.endpoints.auth_url
      baseUrl                    = local.endpoints.base_url
      upwindCredentialsSecretArn = local.credentials_secret_arn
      lambdaVersion              = var.lambda_version
      lambdaLogLevel             = var.lambda_log_level
      upwindTemplateVersion      = var.lambda_version
      organizationId             = var.upwind_organization_id
    }
  }

  tags = {
    upwind_lambda_log_reporter_version = var.lambda_version
    upwind_module_version              = local.upwind_version
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = var.lambda_log_retention_in_days
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id   = "AllowExecutionFromCloudWatch"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.this.function_name
  principal      = "logs.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id

  depends_on = [aws_cloudwatch_log_group.lambda]
}

resource "aws_cloudwatch_log_subscription_filter" "this" {
  for_each        = toset(local.clusters_log_group_names)
  name            = var.cloudwatch_subscription_filter_name
  log_group_name  = each.value
  filter_pattern  = var.filter_pattern
  destination_arn = aws_lambda_function.this.arn

  depends_on = [aws_lambda_permission.allow_cloudwatch]
}

resource "aws_secretsmanager_secret" "upwind_api_credentials" {
  count                          = local.is_secret_created ? 1 : 0
  name                           = "upwindSecurity/api/credentials-${random_uuid.deployment.result}"
  description                    = "Upwind API Credentials"
  recovery_window_in_days        = var.secret_recovery_window_in_days
  force_overwrite_replica_secret = true
}

resource "aws_secretsmanager_secret_version" "upwind_api_credentials" {
  count     = local.is_secret_created ? 1 : 0
  secret_id = aws_secretsmanager_secret.upwind_api_credentials[0].id

  # Seed value only: the lambda caches its access token in this secret at
  # runtime, so Terraform must never reconcile the contents after creation.
  secret_string = jsonencode({
    clientId     = var.upwind_integration_client_id
    clientSecret = var.upwind_integration_client_secret
    accessToken  = null
    expiresAt    = null
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_lambda_invocation" "registration" {
  function_name   = aws_lambda_function.this.function_name
  lifecycle_scope = "CRUD"

  input = jsonencode({
    StackId       = local.stack_id
    lambdaVersion = var.lambda_version
  })

  depends_on = [
    aws_iam_role_policy.cloudwatch_access,
    aws_iam_role_policy.secret_access,
    aws_secretsmanager_secret_version.upwind_api_credentials,
    aws_cloudwatch_log_group.lambda,
    terraform_data.credentials_validator,
  ]
}
