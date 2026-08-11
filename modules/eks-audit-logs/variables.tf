variable "upwind_organization_id" {
  description = "Upwind organization ID."
  type        = string
}

variable "upwind_integration_client_id" {
  description = "Upwind client ID for the integration (ignored when upwind_credentials_secret_arn is set)."
  type        = string
  default     = null
}

variable "upwind_integration_client_secret" {
  description = "Upwind client secret for the integration (ignored when upwind_credentials_secret_arn is set)."
  type        = string
  default     = null
  sensitive   = true
}

variable "upwind_credentials_secret_arn" {
  description = "ARN of an existing Secrets Manager secret holding the Upwind credentials as JSON: {\"clientId\": ..., \"clientSecret\": ...}. When set, no secret is created."
  type        = string
  default     = null
}

variable "upwind_region" {
  description = "Upwind region to connect to (us, eu, me or ap)."
  type        = string
  default     = "us"

  validation {
    condition     = contains(keys(local.upwind_endpoints), var.upwind_region)
    error_message = "upwind_region must be one of: ${join(", ", keys(local.upwind_endpoints))}."
  }
}

variable "lambda_version" {
  description = "Version of the Upwind log reporter lambda release to deploy."
  type        = string
  default     = "1.1.0" # managed-by-release-automation
}

variable "lambda_runtime" {
  description = "Runtime used by the lambda function."
  type        = string
  default     = "python3.12"
}

variable "cluster_names" {
  description = "EKS cluster names to integrate. Leave empty to integrate every cluster in the region that has audit logging enabled."
  type        = list(string)
  default     = []
}

variable "cloudwatch_subscription_filter_name" {
  description = "Name of the CloudWatch Logs subscription filter created on each cluster log group."
  type        = string
  default     = "upwind-audit-only"
}

variable "filter_pattern" {
  description = "CloudWatch Logs subscription filter pattern."
  type        = string
  default     = "audit.k8s.io"
}

variable "lambda_name" {
  description = "Name of the lambda function. Defaults to UpwindLogReporterLambda-<region>."
  type        = string
  default     = null
}

variable "lambda_handler" {
  description = "Lambda handler entrypoint."
  type        = string
  default     = "lambda_function.handler"
}

variable "lambda_memory_size" {
  description = "Memory (MB) allocated to the lambda."
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 300
}

variable "lambda_log_retention_in_days" {
  description = "Retention (days) for the lambda's own log group."
  type        = number
  default     = 90
}

variable "lambda_log_level" {
  description = "Log level for the lambda."
  type        = string
  default     = "WARNING"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.lambda_log_level)
    error_message = "lambda_log_level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
}

variable "lambda_execution_role_name" {
  description = "Name of the lambda execution IAM role. Defaults to <region>-UpwindReportLogsLambdaExecutionRole."
  type        = string
  default     = null
}

variable "cloudwatch_policy_name" {
  description = "Name of the inline IAM policy granting the lambda access to its own log group. Defaults to <region>-AllowUpwindLambdaAccessCloudWatchPolicy."
  type        = string
  default     = null
}

variable "secret_policy_name" {
  description = "Name of the inline IAM policy granting the lambda access to its credentials secret. Defaults to <region>-AllowUpwindLambdaAccessOwnSecretPolicy."
  type        = string
  default     = null
}

variable "s3_policy_name" {
  description = "Name of the inline IAM policy granting the lambda read access to the Upwind functions bucket. Defaults to <region>-AllowUpwindLambdaAccessS3Policy."
  type        = string
  default     = null
}

variable "secret_recovery_window_in_days" {
  description = "Recovery window (days) when the created credentials secret is deleted. 0 forces immediate deletion."
  type        = number
  default     = 30
}
