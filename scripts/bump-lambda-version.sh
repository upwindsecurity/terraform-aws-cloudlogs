#!/usr/bin/env bash
# Open a pull request that points the module at a new log reporter lambda version.
# Usage: scripts/bump-lambda-version.sh <lambda-version>
# Requires: git, gh (authenticated), terraform-docs.
set -euo pipefail

# Take the target lambda version as the only argument.
VER="${1:?usage: scripts/bump-lambda-version.sh <lambda-version>}"

# Accept only a plain X.Y.Z version, since only released lambda builds may be pinned.
if ! [[ "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: '$VER' is not a plain semver version" >&2
  exit 1
fi

# Fail before any work if a required tool is absent.
for tool in gh terraform-docs; do
  if ! command -v "$tool" >/dev/null; then
    echo "error: $tool is not installed" >&2
    exit 1
  fi
done

# Run from the repository root so every path below is stable.
cd "$(git rev-parse --show-toplevel)"

# Refuse a dirty tree so unrelated local edits cannot ride along in the bump PR.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "error: the working tree is not clean" >&2
  exit 1
fi

# Require exactly one marker line, because a lost or duplicated marker would
# otherwise surface as a misleading "already pins" no-op below.
MARKER_COUNT=$(grep -c 'managed-by-release-automation' modules/eks-audit-logs/variables.tf || true)
if [ "${MARKER_COUNT}" -ne 1 ]; then
  echo "error: expected exactly one managed-by-release-automation marker in variables.tf, found ${MARKER_COUNT}" >&2
  exit 1
fi

# Refuse to reuse a branch left behind by an earlier failed run.
BRANCH="bump/log-reporter-${VER}"
if git rev-parse --verify --quiet "refs/heads/${BRANCH}" >/dev/null; then
  echo "error: branch ${BRANCH} already exists (leftover from an earlier run?) — delete it and retry" >&2
  exit 1
fi

# Branch from the remote main so the PR is based on the latest merged state.
git fetch origin main
git checkout -b "${BRANCH}" origin/main

# Rewrite the pinned version on the marker line; the marker comment is the
# contract and the rest of the line may change freely.
sed -i.bak -E "s|(default[[:space:]]*=[[:space:]]*\")[^\"]+(\"[[:space:]]*#[[:space:]]*managed-by-release-automation)|\1${VER}\2|" modules/eks-audit-logs/variables.tf
rm -f modules/eks-audit-logs/variables.tf.bak

# Stop when nothing changed, which means the module already pins this version.
if git diff --quiet; then
  echo "the module already pins lambda ${VER}" >&2
  exit 1
fi

# Regenerate the module README so its inputs table shows the new default.
terraform-docs modules/eks-audit-logs

# Commit with a conventional feat title, since it becomes the public changelog entry.
git commit -am "feat: update log reporter lambda to ${VER}"

# Publish the branch and open the PR whose merge is the prod-verification gate.
git push -u origin "${BRANCH}"
gh pr create \
  --title "feat: update log reporter lambda to ${VER}" \
  --body "Points the module at log reporter lambda ${VER}. Merge after the version is verified in production."
