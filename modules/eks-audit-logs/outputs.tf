output "eks_cluster_names" {
  description = "Names of the EKS clusters that were provided or discovered."
  value       = [for cluster in local.clusters : cluster.name]
}

output "eks_cluster_log_groups" {
  description = "CloudWatch log groups (one per audit-enabled cluster) subscribed to the log reporter."
  value       = local.clusters_log_group_names
}

output "lambda_arn" {
  description = "ARN of the log reporter lambda function."
  value       = aws_lambda_function.this.arn
}

output "credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the Upwind credentials (created or provided)."
  value       = local.credentials_secret_arn
}
