locals {
  upwind_domain = var.upwind_region == "us" ? "upwind.io" : "${var.upwind_region}.upwind.io"
  endpoints = {
    base_url      = "https://integration.${local.upwind_domain}"
    auth_audience = "https://integration.${local.upwind_domain}"
    auth_url      = "https://auth.${local.upwind_domain}/oauth/token"
  }

  aws_region       = data.aws_region.current.region
  lambda_s3_bucket = "upwind-serverless-functions-${local.aws_region}"
  lambda_s3_key    = "log_reporter/${var.lambda_version}.zip"

  lambda_name            = coalesce(var.lambda_name, "UpwindLogReporterLambda-${local.aws_region}")
  execution_role_name    = coalesce(var.lambda_execution_role_name, "${local.aws_region}-UpwindReportLogsLambdaExecutionRole")
  cloudwatch_policy_name = coalesce(var.cloudwatch_policy_name, "${local.aws_region}-AllowUpwindLambdaAccessCloudWatchPolicy")
  secret_policy_name     = coalesce(var.secret_policy_name, "${local.aws_region}-AllowUpwindLambdaAccessOwnSecretPolicy")
  s3_policy_name         = coalesce(var.s3_policy_name, "${local.aws_region}-AllowUpwindLambdaAccessS3Policy")

  is_secret_created      = var.upwind_credentials_secret_arn == null
  credentials_secret_arn = local.is_secret_created ? aws_secretsmanager_secret.upwind_api_credentials[0].arn : var.upwind_credentials_secret_arn

  clusters                 = data.aws_eks_cluster.this
  clusters_log_group_names = [for cluster in local.clusters : "/aws/eks/${cluster.name}/cluster" if contains(cluster.enabled_cluster_log_types, "audit")]

  stack_id = "terraform:${local.upwind_version}:${random_uuid.deployment.result}"
}
