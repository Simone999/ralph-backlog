#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"

  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

setup_fixture() {
  local fixture
  fixture="$(mktemp -d)"

  cp "$REPO_ROOT/ralph.sh" "$fixture/ralph.sh"
  cp "$REPO_ROOT/prompt-codex.md" "$fixture/prompt-codex.md"
  mkdir -p "$fixture/bin"

  cat > "$fixture/bin/codex" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${TMPDIR:-/tmp}/ralph-codex-args.txt"
cat > /dev/null
exit 0
EOF
  chmod +x "$fixture/bin/codex"

  cat > "$fixture/bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$fixture/bin/sleep"

  local cmd
  for cmd in bash cat date dirname grep mkdir sed seq tee; do
    ln -s "$(command -v "$cmd")" "$fixture/bin/$cmd"
  done

  printf '%s\n' "$fixture"
}

run_script() {
  local fixture="$1"
  shift

  (
    cd "$fixture"
    PATH="$fixture/bin" TMPDIR="$fixture/tmp" bash ./ralph.sh "$@"
  ) 2>&1
}

test_rejects_amp() {
  local output status

  set +e
  output="$(cd "$REPO_ROOT" && bash ./ralph.sh --tool amp 1 2>&1)"
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected --tool amp to fail"
  assert_contains "$output" "Invalid tool 'amp'. Must be 'codex'."
}

test_rejects_claude() {
  local output status

  set +e
  output="$(cd "$REPO_ROOT" && bash ./ralph.sh --tool claude 1 2>&1)"
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected --tool claude to fail"
  assert_contains "$output" "Invalid tool 'claude'. Must be 'codex'."
}

test_runs_without_prd_or_jq() {
  local fixture output status

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"

  set +e
  output="$(run_script "$fixture" 1)"
  status=$?
  set -e

  [[ $status -eq 1 ]] || fail "expected single iteration to stop at max iterations"
  assert_contains "$output" "Starting Ralph - Tool: codex - Max iterations: 1"
  assert_contains "$output" "Ralph reached max iterations (1) without completing all tasks."
}

test_rejects_amp
test_rejects_claude
test_runs_without_prd_or_jq

printf 'PASS: ralph runtime\n'
