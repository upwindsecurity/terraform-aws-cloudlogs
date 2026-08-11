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
  cluster_names                    = ["alpha", "beta"]
}

run "one_filter_per_audit_enabled_cluster" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_log_subscription_filter.this) == 2
    error_message = "Every audit-enabled cluster must get a subscription filter"
  }

  assert {
    condition     = contains(keys(aws_cloudwatch_log_subscription_filter.this), "/aws/eks/alpha/cluster")
    error_message = "Filter must target the cluster's EKS log group"
  }

  assert {
    # An empty or broadened pattern would stream the full control-plane
    # firehose instead of audit events only — real customer cost.
    condition     = aws_cloudwatch_log_subscription_filter.this["/aws/eks/alpha/cluster"].filter_pattern == "audit.k8s.io"
    error_message = "Filter pattern must default to audit-only events"
  }

  assert {
    condition     = aws_cloudwatch_log_subscription_filter.this["/aws/eks/alpha/cluster"].name == "upwind-audit-only"
    error_message = "Filter name must default to upwind-audit-only"
  }
}

run "non_audit_clusters_are_skipped" {
  command = plan

  override_data {
    target = data.aws_eks_cluster.this["beta"]
    values = {
      enabled_cluster_log_types = ["api", "authenticator"]
    }
  }

  assert {
    condition     = length(aws_cloudwatch_log_subscription_filter.this) == 1
    error_message = "Clusters without audit logging must be skipped"
  }
}
