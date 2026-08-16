# Upwind EKS Audit Logs Terraform module

Deploys the Upwind log reporter Lambda and connects the EKS clusters in the
current AWS region to Upwind: each audit-enabled cluster's CloudWatch log
group gets a subscription filter that streams Kubernetes audit events to the
Lambda, which forwards them to Upwind.

> **Note on credential rotation:** the module seeds the credentials secret once and
> never rewrites it afterwards (the Lambda caches an access token in the same
> secret at runtime). Changing `upwind_integration_client_id`/`_secret` after the
> initial apply therefore has no effect on the stored secret — update the secret
> value directly in AWS Secrets Manager, or manage credentials yourself via
> `upwind_credentials_secret_arn`.

## Troubleshooting

**`terraform destroy` fails on the registration step** — for example when the
Lambda function or the credentials secret was deleted outside Terraform, the
deregistration call cannot run. Remove the registration resource from state
and destroy again:

```bash
terraform state rm 'module.<your-module-name>.aws_lambda_invocation.registration'
terraform destroy
```

**`terraform apply` fails with `ResourceAlreadyExistsException` on the log group** — a
log group named `/aws/lambda/UpwindLogReporterLambda-<region>` can already exist, for
example when a previous deployment of the log reporter was removed but its log group
was retained (AWS Lambda also recreates log groups automatically when a function
logs during teardown). Import it instead of creating it:

```bash
terraform import 'module.<your-module-name>.aws_cloudwatch_log_group.lambda' /aws/lambda/UpwindLogReporterLambda-<region>
terraform apply
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.5 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_subscription_filter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_subscription_filter) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cloudwatch_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.secret_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_invocation.registration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_permission.allow_cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_secretsmanager_secret.upwind_api_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.upwind_api_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [random_uuid.deployment](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |
| [terraform_data.credentials_validator](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_eks_clusters.all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_clusters) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudwatch_policy_name"></a> [cloudwatch\_policy\_name](#input\_cloudwatch\_policy\_name) | Name of the inline IAM policy granting the lambda access to its own log group. Defaults to <region>-AllowUpwindLambdaAccessCloudWatchPolicy. | `string` | `null` | no |
| <a name="input_cloudwatch_subscription_filter_name"></a> [cloudwatch\_subscription\_filter\_name](#input\_cloudwatch\_subscription\_filter\_name) | Name of the CloudWatch Logs subscription filter created on each cluster log group. | `string` | `"upwind-audit-only"` | no |
| <a name="input_cluster_names"></a> [cluster\_names](#input\_cluster\_names) | EKS cluster names to integrate. Leave empty to integrate every cluster in the region that has audit logging enabled. | `list(string)` | `[]` | no |
| <a name="input_filter_pattern"></a> [filter\_pattern](#input\_filter\_pattern) | CloudWatch Logs subscription filter pattern. | `string` | `"audit.k8s.io"` | no |
| <a name="input_lambda_execution_role_name"></a> [lambda\_execution\_role\_name](#input\_lambda\_execution\_role\_name) | Name of the lambda execution IAM role. Defaults to <region>-UpwindReportLogsLambdaExecutionRole. | `string` | `null` | no |
| <a name="input_lambda_handler"></a> [lambda\_handler](#input\_lambda\_handler) | Lambda handler entrypoint. | `string` | `"lambda_function.handler"` | no |
| <a name="input_lambda_log_level"></a> [lambda\_log\_level](#input\_lambda\_log\_level) | Log level for the lambda. | `string` | `"WARNING"` | no |
| <a name="input_lambda_log_retention_in_days"></a> [lambda\_log\_retention\_in\_days](#input\_lambda\_log\_retention\_in\_days) | Retention (days) for the lambda's own log group. | `number` | `90` | no |
| <a name="input_lambda_memory_size"></a> [lambda\_memory\_size](#input\_lambda\_memory\_size) | Memory (MB) allocated to the lambda. | `number` | `128` | no |
| <a name="input_lambda_name"></a> [lambda\_name](#input\_lambda\_name) | Name of the lambda function. Defaults to UpwindLogReporterLambda-<region>. | `string` | `null` | no |
| <a name="input_lambda_reserved_concurrent_executions"></a> [lambda\_reserved\_concurrent\_executions](#input\_lambda\_reserved\_concurrent\_executions) | Reserved concurrent executions for the lambda. 0 throttles the lambda entirely. null leaves concurrency unreserved. | `number` | `null` | no |
| <a name="input_lambda_runtime"></a> [lambda\_runtime](#input\_lambda\_runtime) | Runtime used by the lambda function. | `string` | `"python3.12"` | no |
| <a name="input_lambda_timeout"></a> [lambda\_timeout](#input\_lambda\_timeout) | Lambda timeout in seconds. | `number` | `300` | no |
| <a name="input_lambda_version"></a> [lambda\_version](#input\_lambda\_version) | Version of the Upwind log reporter lambda release to deploy. | `string` | `"1.1.0"` | no |
| <a name="input_s3_policy_name"></a> [s3\_policy\_name](#input\_s3\_policy\_name) | Name of the inline IAM policy granting the lambda read access to the Upwind functions bucket. Defaults to <region>-AllowUpwindLambdaAccessS3Policy. | `string` | `null` | no |
| <a name="input_secret_policy_name"></a> [secret\_policy\_name](#input\_secret\_policy\_name) | Name of the inline IAM policy granting the lambda access to its credentials secret. Defaults to <region>-AllowUpwindLambdaAccessOwnSecretPolicy. | `string` | `null` | no |
| <a name="input_secret_recovery_window_in_days"></a> [secret\_recovery\_window\_in\_days](#input\_secret\_recovery\_window\_in\_days) | Recovery window (days) when the created credentials secret is deleted. 0 forces immediate deletion. | `number` | `30` | no |
| <a name="input_upwind_credentials_secret_arn"></a> [upwind\_credentials\_secret\_arn](#input\_upwind\_credentials\_secret\_arn) | ARN of an existing Secrets Manager secret holding the Upwind credentials as JSON: {"clientId": ..., "clientSecret": ...}. When set, no secret is created. | `string` | `null` | no |
| <a name="input_upwind_integration_client_id"></a> [upwind\_integration\_client\_id](#input\_upwind\_integration\_client\_id) | Upwind client ID for the integration (ignored when upwind\_credentials\_secret\_arn is set). | `string` | `null` | no |
| <a name="input_upwind_integration_client_secret"></a> [upwind\_integration\_client\_secret](#input\_upwind\_integration\_client\_secret) | Upwind client secret for the integration (ignored when upwind\_credentials\_secret\_arn is set). | `string` | `null` | no |
| <a name="input_upwind_organization_id"></a> [upwind\_organization\_id](#input\_upwind\_organization\_id) | Upwind organization ID. | `string` | n/a | yes |
| <a name="input_upwind_region"></a> [upwind\_region](#input\_upwind\_region) | Upwind region to connect to (us, eu, me or ap). | `string` | `"us"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_credentials_secret_arn"></a> [credentials\_secret\_arn](#output\_credentials\_secret\_arn) | ARN of the Secrets Manager secret holding the Upwind credentials (created or provided). |
| <a name="output_eks_cluster_log_groups"></a> [eks\_cluster\_log\_groups](#output\_eks\_cluster\_log\_groups) | CloudWatch log groups (one per audit-enabled cluster) subscribed to the log reporter. |
| <a name="output_eks_cluster_names"></a> [eks\_cluster\_names](#output\_eks\_cluster\_names) | Names of the EKS clusters that were provided or discovered. |
| <a name="output_lambda_arn"></a> [lambda\_arn](#output\_lambda\_arn) | ARN of the log reporter lambda function. |
<!-- END_TF_DOCS -->
