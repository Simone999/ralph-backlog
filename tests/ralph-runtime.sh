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
cat > "${TMPDIR:-/tmp}/ralph-codex-stdin.txt"
if [[ -n "${MOCK_CODEX_OUTPUT:-}" ]]; then
  printf '%s' "$MOCK_CODEX_OUTPUT"
elif [[ "${MOCK_CODEX_SUPPRESS_OUTPUT:-0}" != "1" ]]; then
  printf '%s\n' '{"type":"thread.started","thread_id":"mock-session-123"}'
fi
exit "${MOCK_CODEX_EXIT:-0}"
EOF
  chmod +x "$fixture/bin/codex"

  cat > "$fixture/bin/backlog" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mock_dir="${MOCK_BACKLOG_DIR:?}"

if [[ "${1:-}" == "task" && "${2:-}" == "list" ]]; then
  cat "$mock_dir/task-list.txt"
  exit 0
fi

if [[ "${1:-}" == "task" && "${2:-}" == "edit" && -n "${3:-}" ]]; then
  task_id="${3,,}"
  task_file="$mock_dir/${task_id}.txt"
  [[ -f "$task_file" ]] || exit 1
  shift 3

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s)
        status="$2"
        shift 2
        sed -i "s/^Status: .*/Status: ○ $status/" "$task_file"
        ;;
      -a)
        assignee="$2"
        shift 2
        if grep -q '^Assignee:' "$task_file"; then
          sed -i "s/^Assignee: .*/Assignee: $assignee/" "$task_file"
        else
          printf '\nAssignee: %s\n' "$assignee" >> "$task_file"
        fi
        ;;
      *)
        printf 'unexpected backlog edit args: %s\n' "$*" >&2
        exit 1
        ;;
    esac
  done

  printf '%s\n' "$(cat "$task_file")" > "$mock_dir/last-edited-task.txt"
  exit 0
fi

if [[ "${1:-}" == "task" && -n "${2:-}" ]]; then
  task_id="${2,,}"
  task_file="$mock_dir/${task_id}.txt"
  if [[ -f "$task_file" ]]; then
    cat "$task_file"
  else
    printf 'Task %s not found.\n' "$2"
  fi
  exit 0
fi

printf 'unexpected backlog args: %s\n' "$*" >&2
exit 1
EOF
  chmod +x "$fixture/bin/backlog"

  cat > "$fixture/bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$fixture/bin/sleep"

  local cmd
  for cmd in bash cat date dirname grep mkdir sed seq tee tr; do
    ln -s "$(command -v "$cmd")" "$fixture/bin/$cmd"
  done

  mkdir -p "$fixture/mock-backlog"
  printf '%s\n' "$fixture"
}

run_script() {
  local fixture="$1"
  shift

  (
    cd "$fixture"
    PATH="$fixture/bin" TMPDIR="$fixture/tmp" MOCK_BACKLOG_DIR="$fixture/mock-backlog" bash ./ralph.sh "$@"
  ) 2>&1
}

write_task_list() {
  local fixture="$1"
  local content="$2"

  printf '%s\n' "$content" > "$fixture/mock-backlog/task-list.txt"
}

write_task_plain() {
  local fixture="$1"
  local task_id="$2"
  local content="$3"

  printf '%s\n' "$content" > "$fixture/mock-backlog/${task_id}.txt"
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
  write_task_list "$fixture" $'To Do:\n  [LOW] TASK-1 - Low todo'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - Low todo\n==================================================\n\nStatus: ○ To Do\nPriority: Low\nCreated: 2026-04-16 00:00'

  set +e
  output="$(run_script "$fixture" 1)"
  status=$?
  set -e

  [[ $status -eq 1 ]] || fail "expected single iteration to stop at max iterations"
  assert_contains "$output" "Starting Ralph - Tool: codex - Max iterations: 1"
  assert_contains "$output" "Ralph reached max iterations (1) without completing all tasks."
}

test_selects_highest_priority_dependency_ready_todo() {
  local fixture output status codex_input

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [HIGH] TASK-2 - High blocked\n  [MEDIUM] TASK-3 - Medium todo\n  [LOW] TASK-1 - Low todo'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - Low todo\n==================================================\n\nStatus: ○ To Do\nPriority: Low\nCreated: 2026-04-16 00:00'
  write_task_plain "$fixture" "task-2" $'File: mock/task-2.md\n\nTask TASK-2 - High blocked\n==================================================\n\nStatus: ○ To Do\nPriority: High\nCreated: 2026-04-16 00:00\nDependencies: TASK-1'
  write_task_plain "$fixture" "task-3" $'File: mock/task-3.md\n\nTask TASK-3 - Medium todo\n==================================================\n\nStatus: ○ To Do\nPriority: Medium\nCreated: 2026-04-16 00:00'

  set +e
  output="$(run_script "$fixture" 1)"
  status=$?
  set -e

  [[ $status -eq 1 ]] || fail "expected single iteration to stop at max iterations"
  codex_input="$(cat "$fixture/tmp/ralph-codex-stdin.txt")"
  assert_contains "$output" "Starting Ralph - Tool: codex - Max iterations: 1"
  assert_contains "$codex_input" "Task TASK-3 - Medium todo"
}

test_sequence_cli_uses_explicit_order() {
  local fixture output status codex_input

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [HIGH] TASK-2 - High blocked\n  [MEDIUM] TASK-3 - Medium todo\n  [LOW] TASK-1 - Low todo'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - First forced task\n==================================================\n\nStatus: ○ To Do\nPriority: Low\nCreated: 2026-04-16 00:00'
  write_task_plain "$fixture" "task-3" $'File: mock/task-3.md\n\nTask TASK-3 - Later forced task\n==================================================\n\nStatus: ○ To Do\nPriority: Medium\nCreated: 2026-04-16 00:00'

  set +e
  output="$(run_script "$fixture" --sequence task-1,task-3 1)"
  status=$?
  set -e

  [[ $status -eq 1 ]] || fail "expected single iteration to stop at max iterations"
  codex_input="$(cat "$fixture/tmp/ralph-codex-stdin.txt")"
  assert_contains "$output" "Starting Ralph - Tool: codex - Max iterations: 1"
  assert_contains "$codex_input" "Task TASK-1 - First forced task"
}

test_sequence_file_uses_explicit_order() {
  local fixture output status codex_input

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  printf 'task-3\n' > "$fixture/sequence.txt"
  write_task_list "$fixture" $'To Do:\n  [HIGH] TASK-2 - High blocked\n  [MEDIUM] TASK-3 - Medium todo'
  write_task_plain "$fixture" "task-3" $'File: mock/task-3.md\n\nTask TASK-3 - From sequence file\n==================================================\n\nStatus: ○ To Do\nPriority: Medium\nCreated: 2026-04-16 00:00'

  set +e
  output="$(run_script "$fixture" --sequence-file "$fixture/sequence.txt" 1)"
  status=$?
  set -e

  [[ $status -eq 1 ]] || fail "expected single iteration to stop at max iterations"
  codex_input="$(cat "$fixture/tmp/ralph-codex-stdin.txt")"
  assert_contains "$output" "Starting Ralph - Tool: codex - Max iterations: 1"
  assert_contains "$codex_input" "Task TASK-3 - From sequence file"
}

test_sequence_missing_task_fails_fast() {
  local fixture output status

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [LOW] TASK-1 - Low todo'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - Low todo\n==================================================\n\nStatus: ○ To Do\nPriority: Low\nCreated: 2026-04-16 00:00'

  set +e
  output="$(run_script "$fixture" --sequence task-9 1)"
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected missing sequence task to fail"
  assert_contains "$output" "Sequence task 'task-9' not found in backlog."
  [[ ! -f "$fixture/tmp/ralph-codex-stdin.txt" ]] || fail "expected codex not to run when sequence task is missing"
}

test_captures_fresh_session_id_and_writes_codex_assignee() {
  local fixture output status edited_task

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [HIGH] TASK-1 - Fresh task'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - Fresh task\n==================================================\n\nStatus: ○ To Do\nPriority: High\nCreated: 2026-04-16 00:00'

  set +e
  output="$(MOCK_CODEX_OUTPUT=$'{"type":"thread.started","thread_id":"session-fresh-123"}\n{"type":"turn.completed","usage":{"input_tokens":0,"cached_input_tokens":0,"output_tokens":0}}' run_script "$fixture" 1)"
  status=$?
  set -e

  [[ $status -eq 1 ]] || fail "expected single iteration to stop at max iterations"
  edited_task="$(cat "$fixture/mock-backlog/last-edited-task.txt")"
  assert_contains "$output" "Using Codex session session-fresh-123 for task task-1"
  assert_contains "$edited_task" "Status: ○ In Progress"
  assert_contains "$edited_task" "Assignee: codex@session-fresh-123"
}

test_fails_loudly_when_fresh_codex_session_id_is_missing() {
  local fixture output status edited_task

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [HIGH] TASK-1 - Fresh task'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - Fresh task\n==================================================\n\nStatus: ○ To Do\nPriority: High\nCreated: 2026-04-16 00:00'

  set +e
  output="$(MOCK_CODEX_SUPPRESS_OUTPUT=1 run_script "$fixture" 1)"
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected missing session id to fail"
  assert_contains "$output" "failed to capture Codex session id for task 'task-1'"
  edited_task="$(cat "$fixture/mock-backlog/last-edited-task.txt")"
  assert_contains "$edited_task" "Status: ○ In Progress"
}

test_resumes_prior_session_from_assignee_metadata() {
  local fixture output status edited_task

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [LOW] TASK-9 - Other task'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - Resume task\n==================================================\n\nStatus: ○ In Progress\nAssignee: codex@resume-123\nPriority: High\nCreated: 2026-04-16 00:00'

  set +e
  output="$(run_script "$fixture" --sequence task-1 1)"
  status=$?
  set -e

  [[ $status -eq 1 ]] || fail "expected single iteration to stop at max iterations"
  edited_task="$(cat "$fixture/mock-backlog/last-edited-task.txt")"
  assert_contains "$output" "Using Codex session resume-123 for task task-1"
  assert_contains "$edited_task" "Status: ○ In Progress"
  assert_contains "$edited_task" "Assignee: codex@resume-123"
}

test_rejects_amp
test_rejects_claude
test_runs_without_prd_or_jq
test_selects_highest_priority_dependency_ready_todo
test_sequence_cli_uses_explicit_order
test_sequence_file_uses_explicit_order
test_sequence_missing_task_fails_fast
test_captures_fresh_session_id_and_writes_codex_assignee
test_fails_loudly_when_fresh_codex_session_id_is_missing
test_resumes_prior_session_from_assignee_metadata

printf 'PASS: ralph runtime\n'
