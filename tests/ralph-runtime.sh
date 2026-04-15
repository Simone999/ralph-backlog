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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"

  [[ "$haystack" != *"$needle"* ]] || fail "expected output to not contain: $needle"
}

setup_fixture() {
  local fixture
  fixture="$(mktemp -d)"

  cp "$REPO_ROOT/ralph.sh" "$fixture/ralph.sh"
  cp "$REPO_ROOT/prompt-codex.md" "$fixture/prompt-codex.md"
  cp "$REPO_ROOT/prompt-verifier.md" "$fixture/prompt-verifier.md"
  mkdir -p "$fixture/bin"

  cat > "$fixture/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

tmp_root="${TMPDIR:-/tmp}"
count_file="$tmp_root/ralph-codex-call-count"
call_count=0
if [[ -f "$count_file" ]]; then
  call_count="$(cat "$count_file")"
fi
call_count=$((call_count + 1))
printf '%s\n' "$call_count" > "$count_file"

printf '%s\n' "$*" > "$tmp_root/ralph-codex-args.txt"
printf '%s\n' "$*" > "$tmp_root/ralph-codex-args-$call_count.txt"
cat > "$tmp_root/ralph-codex-stdin.txt"
cp "$tmp_root/ralph-codex-stdin.txt" "$tmp_root/ralph-codex-stdin-$call_count.txt"

output_file=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  if [[ "${args[$i]}" == "-o" && $((i + 1)) -lt ${#args[@]} ]]; then
    output_file="${args[$((i + 1))]}"
    break
  fi
done

output_var="MOCK_CODEX_OUTPUT_$call_count"
suppress_var="MOCK_CODEX_SUPPRESS_OUTPUT_$call_count"
exit_var="MOCK_CODEX_EXIT_$call_count"
last_message_var="MOCK_CODEX_LAST_MESSAGE_$call_count"
output_value="${!output_var:-${MOCK_CODEX_OUTPUT:-}}"
suppress_value="${!suppress_var:-${MOCK_CODEX_SUPPRESS_OUTPUT:-0}}"
exit_value="${!exit_var:-${MOCK_CODEX_EXIT:-0}}"
last_message_value="${!last_message_var:-${MOCK_CODEX_LAST_MESSAGE:-}}"

if [[ -n "$output_file" ]]; then
  printf '%s' "$last_message_value" > "$output_file"
fi

if [[ -n "$output_value" ]]; then
  printf '%s' "$output_value"
elif [[ "$suppress_value" != "1" ]]; then
  printf '%s\n' '{"type":"thread.started","thread_id":"mock-session-123"}'
  printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":0,"cached_input_tokens":0,"output_tokens":0}}'
fi
exit "$exit_value"
EOF
  chmod +x "$fixture/bin/codex"

  cat > "$fixture/bin/backlog" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mock_dir="${MOCK_BACKLOG_DIR:?}"

if [[ "${1:-}" == "task" && "${2:-}" == "list" ]]; then
  status="To Do"
  shift 2

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s)
        status="${2:-}"
        shift 2
        ;;
      --sort)
        shift 2
        ;;
      --plain)
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  list_file="$mock_dir/task-list-${status// /-}.txt"
  cat "$list_file"
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
      --append-notes)
        notes="$2"
        shift 2
        if grep -q '^Implementation Notes:$' "$task_file"; then
          printf '\n%s\n' "$notes" >> "$task_file"
        else
          printf '\nImplementation Notes:\n%s\n' "$notes" >> "$task_file"
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
  for cmd in bash cat cp date dirname grep mkdir sed seq tee tr; do
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

  write_task_list_for_status "$fixture" "To Do" "$content"
}

write_task_list_for_status() {
  local fixture="$1"
  local status="$2"
  local content="$3"

  printf '%s\n' "$content" > "$fixture/mock-backlog/task-list-${status// /-}.txt"
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

test_rejects_invalid_verify_mode() {
  local output status

  set +e
  output="$(cd "$REPO_ROOT" && bash ./ralph.sh --verify broken 1 2>&1)"
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected invalid --verify value to fail"
  assert_contains "$output" "Invalid verify mode 'broken'. Must be one of: none, same-session, new-session."
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

test_default_mode_ignores_review_failed_tasks() {
  local fixture output status codex_input

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [MEDIUM] TASK-2 - Fresh todo'
  write_task_list_for_status "$fixture" "Review Failed" $'Review Failed:\n  [HIGH] TASK-1 - Failed review task'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - Failed review task\n==================================================\n\nStatus: ○ Review Failed\nPriority: High\nCreated: 2026-04-16 00:00\nAssignee: codex@resume-review-123'
  write_task_plain "$fixture" "task-2" $'File: mock/task-2.md\n\nTask TASK-2 - Fresh todo\n==================================================\n\nStatus: ○ To Do\nPriority: Medium\nCreated: 2026-04-16 00:00'

  set +e
  output="$(run_script "$fixture" 1)"
  status=$?
  set -e

  [[ $status -eq 1 ]] || fail "expected single iteration to stop at max iterations"
  codex_input="$(cat "$fixture/tmp/ralph-codex-stdin.txt")"
  assert_contains "$output" "Starting Ralph - Tool: codex - Max iterations: 1"
  assert_contains "$codex_input" "Task TASK-2 - Fresh todo"
  assert_not_contains "$codex_input" "Task TASK-1 - Failed review task"
}

test_retry_review_failed_prefers_review_failed_task() {
  local fixture output status codex_input codex_args

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [MEDIUM] TASK-2 - Fresh todo'
  write_task_list_for_status "$fixture" "Review Failed" $'Review Failed:\n  [HIGH] TASK-1 - Failed review task'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - Failed review task\n==================================================\n\nStatus: ○ Review Failed\nPriority: High\nCreated: 2026-04-16 00:00\nAssignee: codex@resume-review-123'
  write_task_plain "$fixture" "task-2" $'File: mock/task-2.md\n\nTask TASK-2 - Fresh todo\n==================================================\n\nStatus: ○ To Do\nPriority: Medium\nCreated: 2026-04-16 00:00'

  set +e
  output="$(run_script "$fixture" --retry-review-failed 1)"
  status=$?
  set -e

  [[ $status -eq 1 ]] || fail "expected single iteration to stop at max iterations"
  codex_input="$(cat "$fixture/tmp/ralph-codex-stdin.txt")"
  codex_args="$(cat "$fixture/tmp/ralph-codex-args.txt")"
  assert_contains "$output" "Starting Ralph - Tool: codex - Max iterations: 1"
  assert_contains "$codex_input" "Task TASK-1 - Failed review task"
  assert_not_contains "$codex_input" "Task TASK-2 - Fresh todo"
  assert_contains "$codex_args" "resume"
  assert_contains "$codex_args" "resume-review-123"
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
  local fixture output status edited_task codex_args

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
  codex_args="$(cat "$fixture/tmp/ralph-codex-args.txt")"
  edited_task="$(cat "$fixture/mock-backlog/last-edited-task.txt")"
  assert_contains "$output" "Using Codex session resume-123 for task task-1"
  assert_contains "$codex_args" "exec"
  assert_contains "$codex_args" "resume"
  assert_contains "$codex_args" "resume-123"
  assert_contains "$edited_task" "Status: ○ In Progress"
  assert_contains "$edited_task" "Assignee: codex@resume-123"
}

test_fails_when_worker_reports_turn_failed() {
  local fixture output status edited_task

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [HIGH] TASK-1 - Failing task'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - Failing task\n==================================================\n\nStatus: ○ To Do\nPriority: High\nCreated: 2026-04-16 00:00'

  set +e
  output="$(MOCK_CODEX_OUTPUT=$'{"type":"thread.started","thread_id":"session-fail-123"}\n{"type":"turn.failed","error":"worker exploded"}' run_script "$fixture" 1)"
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected turn.failed outcome to fail"
  assert_contains "$output" "Codex worker reported failure for task 'task-1': worker exploded"
  edited_task="$(cat "$fixture/mock-backlog/last-edited-task.txt")"
  assert_contains "$edited_task" "Status: ○ In Progress"
  assert_contains "$edited_task" "Assignee: codex@session-fail-123"
}

test_fails_when_worker_outcome_is_unclear() {
  local fixture output status edited_task

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [HIGH] TASK-1 - Unclear task'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - Unclear task\n==================================================\n\nStatus: ○ To Do\nPriority: High\nCreated: 2026-04-16 00:00'

  set +e
  output="$(MOCK_CODEX_OUTPUT=$'{"type":"thread.started","thread_id":"session-unclear-123"}\n{"type":"item.completed","item":{"type":"message","content":[]}}' run_script "$fixture" 1)"
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected unclear outcome to fail"
  assert_contains "$output" "Codex worker ended without a clear outcome for task 'task-1'"
  edited_task="$(cat "$fixture/mock-backlog/last-edited-task.txt")"
  assert_contains "$edited_task" "Status: ○ In Progress"
  assert_contains "$edited_task" "Assignee: codex@session-unclear-123"
}

test_passes_task_scoped_worker_prompt_to_codex() {
  local fixture output status codex_input

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [HIGH] TASK-1 - Prompt task'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - Prompt task\n==================================================\n\nStatus: ○ To Do\nPriority: High\nCreated: 2026-04-16 00:00'

  set +e
  output="$(run_script "$fixture" 1)"
  status=$?
  set -e

  [[ $status -eq 1 ]] || fail "expected single iteration to stop at max iterations"
  codex_input="$(cat "$fixture/tmp/ralph-codex-stdin.txt")"
  assert_contains "$output" "Starting Ralph - Tool: codex - Max iterations: 1"
  assert_contains "$codex_input" 'Assigned backlog task from `backlog task task-1 --plain`:'
  assert_not_contains "$codex_input" 'Read the PRD at `[PRD]`'
  assert_not_contains "$codex_input" 'Pick the **highest priority** user story where `passes: false`'
  assert_not_contains "$codex_input" 'Update the PRD to set `passes: true` for the completed story'
  assert_contains "$codex_input" 'Write implementation plan into assigned backlog task before coding.'
  assert_contains "$codex_input" 'Use `backlog task edit <id> --plan`'
  assert_contains "$codex_input" 'You may create, edit, or remove weak acceptance criteria and definition-of-done items before implementation.'
  assert_contains "$codex_input" 'Use `--ac`, `--remove-ac`, `--dod`, and `--remove-dod` through `backlog task edit`.'
  assert_contains "$codex_input" 'Check acceptance criteria and definition-of-done items only when work is truly complete.'
  assert_contains "$codex_input" 'Use repeated `--check-ac` and `--check-dod` flags, never comma lists or ranges.'
  assert_contains "$codex_input" 'Write final summary into backlog task before returning control to Ralph.'
  assert_contains "$codex_input" 'Use `backlog task edit <id> --final-summary`'
}

test_verification_none_skips_verifier_pass() {
  local fixture output status codex_input

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [HIGH] TASK-1 - No verify task'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - No verify task\n==================================================\n\nStatus: ○ To Do\nPriority: High\nCreated: 2026-04-16 00:00'

  set +e
  output="$(run_script "$fixture" --verify none 1)"
  status=$?
  set -e

  [[ $status -eq 1 ]] || fail "expected single iteration to stop at max iterations"
  codex_input="$(cat "$fixture/tmp/ralph-codex-stdin-1.txt")"
  assert_contains "$output" "Starting Ralph - Tool: codex - Max iterations: 1"
  assert_contains "$codex_input" '# Ralph Codex Worker Instructions'
  [[ ! -f "$fixture/tmp/ralph-codex-stdin-2.txt" ]] || fail "expected verifier pass to stay disabled in --verify none mode"
}

test_same_session_verification_reuses_worker_session() {
  local fixture output status verifier_args verifier_input edited_task

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [HIGH] TASK-1 - Same session verify'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - Same session verify\n==================================================\n\nStatus: ○ To Do\nPriority: High\nCreated: 2026-04-16 00:00'

  set +e
  output="$(MOCK_CODEX_OUTPUT_1=$'{"type":"thread.started","thread_id":"worker-session-123"}\n{"type":"turn.completed","usage":{"input_tokens":0,"cached_input_tokens":0,"output_tokens":0}}' MOCK_CODEX_OUTPUT_2=$'{"type":"turn.completed","usage":{"input_tokens":0,"cached_input_tokens":0,"output_tokens":0}}' MOCK_CODEX_LAST_MESSAGE_2=$'<verification>PASS</verification>\nVerifier pass.' run_script "$fixture" --verify same-session 1)"
  status=$?
  set -e

  [[ $status -eq 1 ]] || fail "expected single iteration to stop at max iterations"
  verifier_args="$(cat "$fixture/tmp/ralph-codex-args-2.txt")"
  verifier_input="$(cat "$fixture/tmp/ralph-codex-stdin-2.txt")"
  edited_task="$(cat "$fixture/mock-backlog/task-1.txt")"
  assert_contains "$output" "Using Codex verification session worker-session-123 for task task-1"
  assert_contains "$verifier_args" "exec"
  assert_contains "$verifier_args" "resume"
  assert_contains "$verifier_args" "worker-session-123"
  assert_contains "$verifier_input" '# Ralph Codex Verifier Instructions'
  assert_contains "$edited_task" "Status: ○ Done"
  assert_contains "$edited_task" "Assignee: codex@worker-session-123"
}

test_new_session_verification_uses_fresh_verifier_session() {
  local fixture output status verifier_args verifier_input

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [HIGH] TASK-1 - New session verify'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - New session verify\n==================================================\n\nStatus: ○ To Do\nPriority: High\nCreated: 2026-04-16 00:00'

  set +e
  output="$(MOCK_CODEX_OUTPUT_1=$'{"type":"thread.started","thread_id":"worker-session-123"}\n{"type":"turn.completed","usage":{"input_tokens":0,"cached_input_tokens":0,"output_tokens":0}}' MOCK_CODEX_OUTPUT_2=$'{"type":"thread.started","thread_id":"verifier-session-456"}\n{"type":"turn.completed","usage":{"input_tokens":0,"cached_input_tokens":0,"output_tokens":0}}' MOCK_CODEX_LAST_MESSAGE_2=$'<verification>PASS</verification>\nVerifier pass.' run_script "$fixture" --verify new-session 1)"
  status=$?
  set -e

  [[ $status -eq 1 ]] || fail "expected single iteration to stop at max iterations"
  verifier_args="$(cat "$fixture/tmp/ralph-codex-args-2.txt")"
  verifier_input="$(cat "$fixture/tmp/ralph-codex-stdin-2.txt")"
  assert_contains "$output" "Using Codex verification session verifier-session-456 for task task-1"
  assert_contains "$verifier_args" "exec"
  assert_not_contains "$verifier_args" "resume"
  assert_contains "$verifier_input" '# Ralph Codex Verifier Instructions'
}

test_fails_when_verifier_rejects_task() {
  local fixture output status edited_task

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [HIGH] TASK-1 - Verify fail task'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - Verify fail task\n==================================================\n\nStatus: ○ To Do\nPriority: High\nCreated: 2026-04-16 00:00'

  set +e
  output="$(MOCK_CODEX_OUTPUT_1=$'{"type":"thread.started","thread_id":"worker-session-123"}\n{"type":"turn.completed","usage":{"input_tokens":0,"cached_input_tokens":0,"output_tokens":0}}' MOCK_CODEX_OUTPUT_2=$'{"type":"thread.started","thread_id":"verifier-session-456"}\n{"type":"turn.completed","usage":{"input_tokens":0,"cached_input_tokens":0,"output_tokens":0}}' MOCK_CODEX_LAST_MESSAGE_2=$'<verification>FAIL</verification>\nReview notes: missing regression coverage.' run_script "$fixture" --verify new-session 1)"
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "expected verifier rejection to fail"
  assert_contains "$output" "Codex verifier rejected task 'task-1': Review notes: missing regression coverage."
  edited_task="$(cat "$fixture/mock-backlog/task-1.txt")"
  assert_contains "$edited_task" "Status: ○ Review Failed"
  assert_contains "$edited_task" "Assignee: codex@worker-session-123"
  assert_contains "$edited_task" "Implementation Notes:"
  assert_contains "$edited_task" "Review notes: missing regression coverage."
}

test_sequence_can_force_review_failed_task_without_retry_flag() {
  local fixture output status codex_input codex_args

  fixture="$(setup_fixture)"
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/tmp"
  write_task_list "$fixture" $'To Do:\n  [LOW] TASK-2 - Fresh todo'
  write_task_plain "$fixture" "task-1" $'File: mock/task-1.md\n\nTask TASK-1 - Forced failed review task\n==================================================\n\nStatus: ○ Review Failed\nPriority: High\nCreated: 2026-04-16 00:00\nAssignee: codex@resume-review-999'
  write_task_plain "$fixture" "task-2" $'File: mock/task-2.md\n\nTask TASK-2 - Fresh todo\n==================================================\n\nStatus: ○ To Do\nPriority: Low\nCreated: 2026-04-16 00:00'

  set +e
  output="$(run_script "$fixture" --sequence task-1 1)"
  status=$?
  set -e

  [[ $status -eq 1 ]] || fail "expected single iteration to stop at max iterations"
  codex_input="$(cat "$fixture/tmp/ralph-codex-stdin.txt")"
  codex_args="$(cat "$fixture/tmp/ralph-codex-args.txt")"
  assert_contains "$output" "Starting Ralph - Tool: codex - Max iterations: 1"
  assert_contains "$codex_input" "Task TASK-1 - Forced failed review task"
  assert_contains "$codex_args" "resume"
  assert_contains "$codex_args" "resume-review-999"
}

test_rejects_amp
test_rejects_claude
test_rejects_invalid_verify_mode
test_runs_without_prd_or_jq
test_selects_highest_priority_dependency_ready_todo
test_default_mode_ignores_review_failed_tasks
test_retry_review_failed_prefers_review_failed_task
test_sequence_cli_uses_explicit_order
test_sequence_file_uses_explicit_order
test_sequence_missing_task_fails_fast
test_captures_fresh_session_id_and_writes_codex_assignee
test_fails_loudly_when_fresh_codex_session_id_is_missing
test_resumes_prior_session_from_assignee_metadata
test_fails_when_worker_reports_turn_failed
test_fails_when_worker_outcome_is_unclear
test_passes_task_scoped_worker_prompt_to_codex
test_verification_none_skips_verifier_pass
test_same_session_verification_reuses_worker_session
test_new_session_verification_uses_fresh_verifier_session
test_fails_when_verifier_rejects_task
test_sequence_can_force_review_failed_task_without_retry_flag

printf 'PASS: ralph runtime\n'
