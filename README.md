# Terraform Modules for AWS Cloud Logs

## Overview

This repository contains Terraform modules for streaming AWS-hosted logs to
[Upwind](https://www.upwind.io) for centralized observability and threat detection.

## Modules

- [modules/eks-audit-logs/](./modules/eks-audit-logs/) - Streams EKS audit logs
  to Upwind via CloudWatch Logs subscription filters and the Upwind log
  reporter Lambda function.

## Examples

- [eks-audit-logs-basic](./examples/eks-audit-logs-basic/) - Connect the EKS
  clusters in a region to Upwind.

## Usage

```hcl
module "upwind_eks_audit_logs" {
  source  = "upwindsecurity/cloudlogs/aws//modules/eks-audit-logs"
  version = "~> 1.0"

  upwind_organization_id           = "your-organization-id"
  upwind_integration_client_id     = "your-client-id"
  upwind_integration_client_secret = "your-client-secret"

  # upwind_region = "eu"          # us (default), eu, me or ap
  # cluster_names = ["prod-1"]    # empty = every audit-enabled cluster in the region
}
```

## Versioning

We use [Semantic Versioning](http://semver.org/) for releases. For the versions
available, see the tags on this repository.

## Releasing

Releases are automated with [release-please](https://github.com/googleapis/release-please).

1. Land changes on `main` through pull requests with
   [Conventional Commit](https://www.conventionalcommits.org) titles
   (`fix:`, `feat:`, ...).
2. release-please opens or updates a release pull request. It carries the
   version bump, the changelog entry, and the version stamp.
3. Merge the release pull request. This creates the `vX.Y.Z` tag and the
   GitHub release. The Terraform Registry picks up the new tag automatically.

### Updating the pinned lambda version

When a new log reporter lambda version is published, run:

```sh
./scripts/bump-lambda-version.sh <lambda-version>
```

The script updates the `lambda_version` default, regenerates the module
docs, and opens the bump pull request. Merge it after the lambda version
is verified in production.

### Manual release

If the automation is unavailable, a release is a pull request plus a tag:

1. Add a section for the new version to `CHANGELOG.md`.
2. Update the version in `modules/eks-audit-logs/module_version.tf`. Keep the
   `# x-release-please-version` marker comment.
3. Set the new version in `.release-please-manifest.json`.
4. If module inputs changed, regenerate the docs:
   `terraform-docs modules/eks-audit-logs`.
5. Open a pull request with these changes and merge it.
6. Tag the merge commit and push the tag:
   `git tag vX.Y.Z && git push origin vX.Y.Z`.
   A repository ruleset restricts `v*` tag creation to the release
   automation, so a repository admin must lift the ruleset for this push
   and restore it afterwards.

The Terraform Registry serves every `vX.Y.Z` tag as a module version.

## License

Apache 2.0 - see [LICENSE](./LICENSE).
