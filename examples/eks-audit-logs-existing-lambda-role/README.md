# eks-audit-logs-existing-lambda-role

Connects every audit-enabled EKS cluster in the region to Upwind, running the lambda as an existing IAM role. The module creates no IAM role or policy. See the `lambda_execution_role_arn` input for the permissions the role needs.

## Usage

```bash
# Keep the client secret out of your shell history: Terraform reads it
# from the environment via the TF_VAR_ prefix.
read -rs TF_VAR_upwind_integration_client_secret && export TF_VAR_upwind_integration_client_secret

terraform init
terraform apply \
  -var upwind_organization_id=... \
  -var upwind_integration_client_id=... \
  -var lambda_execution_role_arn=arn:aws:iam::<account-id>:role/<role-name>
```
