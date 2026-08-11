# eks-audit-logs-basic

Connects every audit-enabled EKS cluster in the region to Upwind.

## Usage

```bash
# Keep the client secret out of your shell history: Terraform reads it
# from the environment via the TF_VAR_ prefix.
read -rs TF_VAR_upwind_integration_client_secret && export TF_VAR_upwind_integration_client_secret

terraform init
terraform apply \
  -var upwind_organization_id=... \
  -var upwind_integration_client_id=...
```
