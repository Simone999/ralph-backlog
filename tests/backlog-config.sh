#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/backlog/config.yml"
EXPECTED_STATUSES='statuses: ["To Do", "In Progress", "Review", "Review Failed", "Done"]'

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

status_count="$(grep -c '^statuses:' "$CONFIG_FILE")"
[[ "$status_count" == "1" ]] || fail "expected exactly one statuses line, got $status_count"

actual_statuses="$(grep '^statuses:' "$CONFIG_FILE")"
[[ "$actual_statuses" == "$EXPECTED_STATUSES" ]] || fail "unexpected statuses line: $actual_statuses"
