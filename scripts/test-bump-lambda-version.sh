#!/usr/bin/env bash
# Tests for bump-lambda-version.sh.
#
# Each test runs the script inside a throwaway clone of this repository with
# a local bare repo standing in for origin, and with `gh` and `terraform-docs`
# replaced by recording stubs on PATH. No network access, no real PRs.
# Usage: scripts/test-bump-lambda-version.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

PASS=0
FAIL=0

pass() { echo "ok: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

# --- stubs ------------------------------------------------------------------

mkdir -p "${WORK}/bin"
cat > "${WORK}/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >> "${GH_LOG:?}"
EOF
cat > "${WORK}/bin/terraform-docs" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${WORK}/bin/gh" "${WORK}/bin/terraform-docs"
export PATH="${WORK}/bin:${PATH}"

# --- sandbox ----------------------------------------------------------------

# Builds a fresh sandbox from the tracked files of the working tree, so the
# tests exercise local changes before they are committed.
SANDBOX_N=0
make_sandbox() {
  SANDBOX_N=$((SANDBOX_N + 1))
  SANDBOX="${WORK}/sandbox-${SANDBOX_N}"
  export GH_LOG="${SANDBOX}.gh.log"
  : > "${GH_LOG}"

  mkdir -p "${SANDBOX}/repo"
  (cd "${ROOT}" && git ls-files -z | tar --null -T - -cf -) | tar -xf - -C "${SANDBOX}/repo"

  git -C "${SANDBOX}/repo" init -q -b main
  git -C "${SANDBOX}/repo" config user.email "test@invalid"
  git -C "${SANDBOX}/repo" config user.name "test"
  git -C "${SANDBOX}/repo" add -A
  git -C "${SANDBOX}/repo" commit -qm "seed"

  git init -q --bare -b main "${SANDBOX}/origin.git"
  git -C "${SANDBOX}/repo" remote add origin "${SANDBOX}/origin.git"
  git -C "${SANDBOX}/repo" push -qu origin main
}

run_bump() {
  (cd "${SANDBOX}/repo" && scripts/bump-lambda-version.sh "$@") \
    > "${SANDBOX}.out" 2> "${SANDBOX}.err"
}

pinned_version() {
  sed -nE 's/.*default[[:space:]]*=[[:space:]]*"([^"]+)".*managed-by-release-automation.*/\1/p' \
    "${SANDBOX}/repo/modules/eks-audit-logs/variables.tf"
}

# --- tests ------------------------------------------------------------------

test_rejects_malformed_versions() {
  make_sandbox
  local bad
  for bad in "1.2" "v1.2.3" "1.2.3-rc1" "1.2.3.4" ""; do
    if run_bump "${bad}"; then
      fail "accepted malformed version '${bad}'"
    else
      pass "rejects malformed version '${bad}'"
    fi
  done
}

test_refuses_dirty_tree() {
  make_sandbox
  echo "local edit" >> "${SANDBOX}/repo/README.md"

  if run_bump "9.9.9"; then
    fail "ran despite a dirty working tree"
  elif grep -q "not clean" "${SANDBOX}.err"; then
    pass "refuses a dirty working tree"
  else
    fail "dirty tree refused without the expected message"
  fi
}

test_refuses_already_pinned_version() {
  make_sandbox
  local current
  current="$(pinned_version)"

  if run_bump "${current}"; then
    fail "re-pinned the already-pinned version ${current}"
  elif grep -q "already pins" "${SANDBOX}.err"; then
    pass "refuses the already-pinned version"
  else
    fail "already-pinned refused without the expected message"
  fi
}

test_refuses_missing_marker() {
  make_sandbox
  sed -i.bak 's|# managed-by-release-automation||' \
    "${SANDBOX}/repo/modules/eks-audit-logs/variables.tf"
  rm -f "${SANDBOX}/repo/modules/eks-audit-logs/variables.tf.bak"
  git -C "${SANDBOX}/repo" commit -qam "drop marker"

  if run_bump "9.9.9"; then
    fail "ran without the marker comment"
  elif grep -q "marker" "${SANDBOX}.err"; then
    pass "refuses when the marker comment is missing"
  else
    fail "missing marker refused without the expected message"
  fi
}

test_refuses_duplicate_marker() {
  make_sandbox
  echo '# managed-by-release-automation' \
    >> "${SANDBOX}/repo/modules/eks-audit-logs/variables.tf"
  git -C "${SANDBOX}/repo" commit -qam "duplicate marker"

  if run_bump "9.9.9"; then
    fail "ran with a duplicated marker comment"
  elif grep -q "found 2" "${SANDBOX}.err"; then
    pass "refuses a duplicated marker comment"
  else
    fail "duplicate marker refused without the expected message"
  fi
}

test_refuses_leftover_branch() {
  make_sandbox
  git -C "${SANDBOX}/repo" branch "bump/log-reporter-9.9.9"

  if run_bump "9.9.9"; then
    fail "ran despite a leftover bump branch"
  elif grep -q "already exists" "${SANDBOX}.err"; then
    pass "refuses a leftover bump branch"
  else
    fail "leftover branch refused without the expected message"
  fi
}

test_happy_path() {
  make_sandbox

  if ! run_bump "9.9.9"; then
    fail "happy path exited non-zero: $(cat "${SANDBOX}.err")"
    return
  fi
  pass "happy path exits zero"

  if [ "$(pinned_version)" = "9.9.9" ]; then
    pass "variables.tf pins the new version with the marker intact"
  else
    fail "variables.tf does not pin 9.9.9 (got: $(pinned_version))"
  fi

  local title
  title="$(git -C "${SANDBOX}/repo" log -1 --format=%s)"
  if [ "${title}" = "feat: update log reporter lambda to 9.9.9" ]; then
    pass "commit title is the conventional feat title"
  else
    fail "unexpected commit title: ${title}"
  fi

  if git -C "${SANDBOX}/origin.git" show-ref --verify -q "refs/heads/bump/log-reporter-9.9.9"; then
    pass "branch is pushed to origin"
  else
    fail "branch missing on origin"
  fi

  if grep -q "gh pr create .*feat: update log reporter lambda to 9.9.9" "${GH_LOG}"; then
    pass "gh pr create is called with the feat title"
  else
    fail "gh pr create call missing or mistitled: $(cat "${GH_LOG}")"
  fi

  if ! git -C "${SANDBOX}/repo" diff --quiet main -- modules/eks-audit-logs/README.md; then
    : # README may change when the real terraform-docs runs; stubbed here.
  fi
  if git -C "${SANDBOX}/repo" status --porcelain | grep -q .; then
    fail "working tree left dirty after the run"
  else
    pass "working tree is clean after the run"
  fi
}

# --- main -------------------------------------------------------------------

test_rejects_malformed_versions
test_refuses_dirty_tree
test_refuses_already_pinned_version
test_refuses_missing_marker
test_refuses_duplicate_marker
test_refuses_leftover_branch
test_happy_path

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
