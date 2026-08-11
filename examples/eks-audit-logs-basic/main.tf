terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "upwind_eks_audit_logs" {
  source = "../../modules/eks-audit-logs"

  upwind_organization_id           = var.upwind_organization_id
  upwind_integration_client_id     = var.upwind_integration_client_id
  upwind_integration_client_secret = var.upwind_integration_client_secret
  upwind_region                    = var.upwind_region
}

output "connected_log_groups" {
  value = module.upwind_eks_audit_logs.eks_cluster_log_groups
}
