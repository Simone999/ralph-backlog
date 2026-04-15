#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [--tool codex] [max_iterations]

set -euo pipefail

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "missing required command: $cmd"
  done
}

normalize_task_id() {
  printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

task_output_has_details() {
  local line
  while IFS= read -r line; do
    if [[ "$line" =~ ^Task[[:space:]]+[A-Z0-9-]+[[:space:]]+-[[:space:]].+$ ]]; then
      return 0
    fi
  done <<< "$1"
  return 1
}

load_task_plain() {
  local task_id task_plain
  task_id="$(normalize_task_id "$1")"

  if ! task_plain="$(backlog task "$task_id" --plain 2>&1)"; then
    die "failed to load backlog task '$task_id'"
  fi

  if ! task_output_has_details "$task_plain"; then
    die "failed to load backlog task '$task_id'"
  fi

  printf '%s\n' "$task_plain"
}

task_exists() {
  local task_id task_plain
  task_id="$(normalize_task_id "$1")"

  if ! task_plain="$(backlog task "$task_id" --plain 2>&1)"; then
    return 1
  fi

  task_output_has_details "$task_plain"
}

extract_task_status() {
  local line
  while IFS= read -r line; do
    case "$line" in
      *"Status:"*"Review Failed")
        printf 'Review Failed\n'
        return 0
        ;;
      *"Status:"*"In Progress")
        printf 'In Progress\n'
        return 0
        ;;
      *"Status:"*"To Do")
        printf 'To Do\n'
        return 0
        ;;
      *"Status:"*"Done")
        printf 'Done\n'
        return 0
        ;;
    esac
  done <<< "$1"
  return 1
}

extract_task_dependencies() {
  local line
  while IFS= read -r line; do
    if [[ "$line" == Dependencies:* ]]; then
      printf '%s\n' "${line#Dependencies: }"
      return 0
    fi
  done <<< "$1"
  return 1
}

extract_task_assignee() {
  local line
  while IFS= read -r line; do
    if [[ "$line" == Assignee:* ]]; then
      printf '%s\n' "${line#Assignee: }"
      return 0
    fi
  done <<< "$1"
  return 1
}

extract_codex_session_id() {
  local assignee="${1:-}"
  if [[ "$assignee" =~ ^codex@([^[:space:]]+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

mark_task_in_progress() {
  local task_id="$1"
  local session_id="${2:-}"

  if [[ -n "$session_id" ]]; then
    if ! backlog task edit "$task_id" -s "In Progress" -a "codex@$session_id" >/dev/null; then
      die "failed to update backlog metadata for task '$task_id'"
    fi
    return 0
  fi

  if ! backlog task edit "$task_id" -s "In Progress" >/dev/null; then
    die "failed to update backlog metadata for task '$task_id'"
  fi
}

write_task_session_assignee() {
  local task_id="$1"
  local session_id="$2"

  if ! backlog task edit "$task_id" -s "In Progress" -a "codex@$session_id" >/dev/null; then
    die "failed to update backlog metadata for task '$task_id'"
  fi
}

extract_verification_status() {
  local verifier_output="$1"

  if [[ "$verifier_output" == *"<verification>PASS</verification>"* ]]; then
    printf 'PASS\n'
    return 0
  fi

  if [[ "$verifier_output" == *"<verification>FAIL</verification>"* ]]; then
    printf 'FAIL\n'
    return 0
  fi

  return 1
}

extract_verification_notes() {
  printf '%s\n' "$1" | sed '/<verification>PASS<\/verification>/d;/<verification>FAIL<\/verification>/d;/^[[:space:]]*$/d'
}

extract_codex_thread_id_from_run_log() {
  local run_file="$1"
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *'"type":"thread.started"'* ]] || continue
    if [[ "$line" =~ \"thread_id\":\"([^\"]+)\" ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  done < "$run_file"

  return 1
}

extract_turn_failure_from_run_log() {
  local run_file="$1"
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *'"type":"turn.failed"'* ]] || continue
    if [[ "$line" =~ \"error\":\"([^\"]+)\" ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
    printf 'unknown error\n'
    return 0
  done < "$run_file"

  return 1
}

run_log_has_turn_completed() {
  local run_file="$1"
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == *'"type":"turn.completed"'* ]]; then
      return 0
    fi
  done < "$run_file"

  return 1
}

dependencies_satisfied() {
  local task_plain dependency_line dependency dep_plain dep_status
  task_plain="$1"

  if ! dependency_line="$(extract_task_dependencies "$task_plain")"; then
    return 0
  fi

  while IFS= read -r dependency; do
    dependency="$(printf '%s\n' "$dependency" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -n "$dependency" ]] || continue

    dep_plain="$(load_task_plain "$dependency")"
    dep_status="$(extract_task_status "$dep_plain")"
    if [[ "$dep_status" != "Done" ]]; then
      return 1
    fi
  done < <(printf '%s\n' "$dependency_line" | tr ',' '\n')

  return 0
}

list_todo_task_ids() {
  local task_list line
  if ! task_list="$(backlog task list -s "To Do" --sort priority --plain 2>&1)"; then
    die "failed to list backlog tasks"
  fi

  while IFS= read -r line; do
    if [[ "$line" =~ \[[A-Z]+\][[:space:]]+([A-Z0-9-]+)[[:space:]]+-[[:space:]].+$ ]]; then
      normalize_task_id "${BASH_REMATCH[1]}"
    fi
  done <<< "$task_list"
}

select_dependency_ready_task() {
  local task_id task_plain
  while IFS= read -r task_id; do
    [[ -n "$task_id" ]] || continue
    task_plain="$(load_task_plain "$task_id")"
    if dependencies_satisfied "$task_plain"; then
      printf '%s\n' "$task_id"
      return 0
    fi
  done < <(list_todo_task_ids)

  die "no dependency-ready 'To Do' backlog task found"
}

SEQUENCE_TASKS=()

append_sequence_items() {
  local item
  while IFS= read -r item; do
    item="$(printf '%s\n' "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -n "$item" ]] || continue
    SEQUENCE_TASKS+=("$(normalize_task_id "$item")")
  done < <(printf '%s\n' "$1" | tr ',' '\n')
}

append_sequence_file() {
  local file_path line
  file_path="$1"
  [[ -f "$file_path" ]] || die "sequence file not found: $file_path"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(printf '%s\n' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -n "$line" ]] || continue
    SEQUENCE_TASKS+=("$(normalize_task_id "$line")")
  done < "$file_path"
}

validate_sequence_tasks() {
  local task_id
  for task_id in "${SEQUENCE_TASKS[@]}"; do
    task_exists "$task_id" || die "Sequence task '$task_id' not found in backlog."
  done
}

select_next_task() {
  local iteration_index="$1"
  if (( iteration_index < ${#SEQUENCE_TASKS[@]} )); then
    printf '%s\n' "${SEQUENCE_TASKS[$iteration_index]}"
    return 0
  fi

  select_dependency_ready_task
}

run_codex(){
  local task_id="$1"
  local prompt="$2"
  local run_file="$3"
  local run_kind="${4:-worker}"
  local session_id="${5:-}"

  local last_message_file="/tmp/$(date -u '+ralph-last-message-%s.txt')"
  local cmd
  mkdir -p "$(dirname "$run_file")"

  if [[ -n "$session_id" ]]; then
    cmd=("${CODEX_RESUME_CMD[@]}" "$session_id" -o "$last_message_file" --json -)
  else
    cmd=("${CODEX_EXEC_CMD[@]}" -o "$last_message_file" --json -)
  fi

  if ! printf '%s' "$prompt" | "${cmd[@]}" > "$run_file"; then
    if [[ -n "$session_id" ]]; then
      die "failed to resume Codex $run_kind for task '$task_id'. Check '$run_file' for details."
    fi
    die "failed to start Codex $run_kind for task '$task_id'. Check '$run_file' for details."
  fi
  cat "$last_message_file" 2>/dev/null || true
}

run_codex_verification() {
  local task_id="$1"
  local task_plain="$2"
  local worker_session_id="$3"
  local verifier_prompt_template verifier_prompt verifier_run_file verifier_output
  local verifier_session_id verification_status verification_notes turn_failure

  verifier_prompt_template="$(cat "$SCRIPT_DIR/prompt-verifier.md")"
  verifier_prompt=$(printf 'Assigned backlog task from `backlog task %s --plain`:\n\n%s\n\n%s' "$task_id" "$task_plain" "$verifier_prompt_template")
  verifier_run_file="$SCRIPT_DIR/runs/$(date -u '+ralph-verify-%s.jsonl')"
  verifier_session_id=""

  if [[ "$VERIFY_MODE" == "same-session" ]]; then
    verifier_session_id="$worker_session_id"
  fi

  verifier_output="$(run_codex "$task_id" "$verifier_prompt" "$verifier_run_file" "verifier" "$verifier_session_id")"

  if [[ -z "$verifier_session_id" ]]; then
    verifier_session_id="$(extract_codex_thread_id_from_run_log "$verifier_run_file" || true)"
    [[ -n "$verifier_session_id" ]] || die "failed to capture Codex verification session id for task '$task_id'"
  fi

  turn_failure="$(extract_turn_failure_from_run_log "$verifier_run_file" || true)"
  if [[ -n "$turn_failure" ]]; then
    die "Codex verifier runtime failed for task '$task_id': $turn_failure"
  fi

  if ! run_log_has_turn_completed "$verifier_run_file"; then
    die "Codex verifier ended without a clear outcome for task '$task_id'"
  fi

  verification_status="$(extract_verification_status "$verifier_output" || true)"
  [[ -n "$verification_status" ]] || die "Codex verifier ended without a verification result for task '$task_id'"

  log "Using Codex verification session $verifier_session_id for task $task_id"

  if [[ "$verification_status" == "FAIL" ]]; then
    verification_notes="$(extract_verification_notes "$verifier_output")"
    [[ -n "$verification_notes" ]] || verification_notes="verification failed"
    die "Codex verifier rejected task '$task_id': $verification_notes"
  fi
}

# Parse arguments
TOOL="codex"
MAX_ITERATIONS="10"
VERIFY_MODE="${RALPH_VERIFY_MODE:-none}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool)
      [[ $# -ge 2 ]] || die "missing value for --tool"
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    --sequence)
      [[ $# -ge 2 ]] || die "missing value for --sequence"
      append_sequence_items "$2"
      shift 2
      ;;
    --sequence=*)
      append_sequence_items "${1#*=}"
      shift
      ;;
    --sequence-file)
      [[ $# -ge 2 ]] || die "missing value for --sequence-file"
      append_sequence_file "$2"
      shift 2
      ;;
    --sequence-file=*)
      append_sequence_file "${1#*=}"
      shift
      ;;
    --verify)
      [[ $# -ge 2 ]] || die "missing value for --verify"
      VERIFY_MODE="$2"
      shift 2
      ;;
    --verify=*)
      VERIFY_MODE="${1#*=}"
      shift
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
        shift
      else
        die "usage: ./ralph.sh [--tool codex] [--sequence task-1,task-2] [--sequence-file path] [--verify none|same-session|new-session] [max_iterations]"
      fi
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "codex" ]]; then
  die "Invalid tool '$TOOL'. Must be 'codex'."
fi

case "$VERIFY_MODE" in
  none|same-session|new-session)
    ;;
  *)
    die "Invalid verify mode '$VERIFY_MODE'. Must be one of: none, same-session, new-session."
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RALPH_MODEL="${RALPH_MODEL:-gpt-5.4}"
RALPH_REASONING="${RALPH_REASONING:-high}"
RALPH_SANDBOX="${RALPH_SANDBOX:-danger-full-access}"
RALPH_APPROVAL_POLICY="${RALPH_APPROVAL_POLICY:-never}"

require_cmd backlog cat codex date grep mkdir sed seq sleep tr

if (( ${#SEQUENCE_TASKS[@]} > 0 )); then
  validate_sequence_tasks
fi


CODEX_COMMON_ARGS=(
  --color never
  -m "$RALPH_MODEL"
  -c "model_reasoning_effort=\"$RALPH_REASONING\""
  -s "$RALPH_SANDBOX"
)

CODEX_EXEC_CMD=(
  codex
  -a "$RALPH_APPROVAL_POLICY"
  exec
  "${CODEX_COMMON_ARGS[@]}"
)

CODEX_RESUME_CMD=(
  codex
  -a "$RALPH_APPROVAL_POLICY"
  exec
  resume
  "${CODEX_COMMON_ARGS[@]}"
)

log "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  task_id="$(select_next_task "$((i - 1))")"
  task_plain="$(load_task_plain "$task_id")"
  assignee="$(extract_task_assignee "$task_plain" || true)"
  session_id="$(extract_codex_session_id "$assignee" || true)"
  mark_task_in_progress "$task_id" "$session_id"
  task_plain="$(load_task_plain "$task_id")"

  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  prompt_template="$(cat "$SCRIPT_DIR/prompt-codex.md")"
  prompt=$(printf 'Assigned backlog task from `backlog task %s --plain`:\n\n%s\n\n%s' "$task_id" "$task_plain" "$prompt_template")
  run_file="$SCRIPT_DIR/runs/$(date -u '+ralph-run-%s.jsonl')"
  OUTPUT=$(run_codex "$task_id" "$prompt" "$run_file" "worker" "$session_id")

  if [[ -z "$session_id" ]]; then
    session_id="$(extract_codex_thread_id_from_run_log "$run_file" || true)"
    [[ -n "$session_id" ]] || die "failed to capture Codex session id for task '$task_id'"
    write_task_session_assignee "$task_id" "$session_id"
  fi

  turn_failure="$(extract_turn_failure_from_run_log "$run_file" || true)"
  if [[ -n "$turn_failure" ]]; then
    die "Codex worker reported failure for task '$task_id': $turn_failure"
  fi

  if ! run_log_has_turn_completed "$run_file"; then
    die "Codex worker ended without a clear outcome for task '$task_id'"
  fi

  log "Using Codex session $session_id for task $task_id"

  if [[ "$VERIFY_MODE" != "none" ]]; then
    run_codex_verification "$task_id" "$task_plain" "$session_id"
  fi
  
  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    log "Ralph completed all tasks!"
    log "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi
  
  log "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
log "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
log "Check Codex run logs under $SCRIPT_DIR/runs for status."
exit 1
