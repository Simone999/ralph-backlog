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
  local prompt="$1"
  local run_file="$2"
  shift 2

  local last_message_file="/tmp/$(date -u '+ralph-last-message-%s.txt')"
  mkdir -p "$(dirname "$run_file")"

  if ! printf '%s' "$prompt" | "${CODEX_BASE_CMD[@]}" -o "$last_message_file" --json - > "$run_file"; then
    die "Codex command failed. Check '$run_file' for details."
  fi
  cat "$last_message_file" 2>/dev/null || true
}

# Parse arguments
TOOL="codex"
MAX_ITERATIONS="10"

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
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
        shift
      else
        die "usage: ./ralph.sh [--tool codex] [--sequence task-1,task-2] [--sequence-file path] [max_iterations]"
      fi
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "codex" ]]; then
  die "Invalid tool '$TOOL'. Must be 'codex'."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RALPH_MODEL="${RALPH_MODEL:-gpt-5.4}"
RALPH_REASONING="${RALPH_REASONING:-high}"
RALPH_SANDBOX="${RALPH_SANDBOX:-danger-full-access}"
RALPH_APPROVAL_POLICY="${RALPH_APPROVAL_POLICY:-never}"

require_cmd backlog cat codex date grep mkdir sed seq sleep tr

if (( ${#SEQUENCE_TASKS[@]} > 0 )); then
  validate_sequence_tasks
fi


CODEX_BASE_CMD=(
  codex
  -a "$RALPH_APPROVAL_POLICY"
  exec
  --color never
  -m "$RALPH_MODEL"
  -c "model_reasoning_effort=\"$RALPH_REASONING\""
  -s "$RALPH_SANDBOX"
)

log "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  task_id="$(select_next_task "$((i - 1))")"
  task_plain="$(load_task_plain "$task_id")"

  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  prompt_template="$(cat "$SCRIPT_DIR/prompt-codex.md")"
  prompt=$(printf 'Assigned backlog task from `backlog task %s --plain`:\n\n%s\n\n%s' "$task_id" "$task_plain" "$prompt_template")
  run_file="$SCRIPT_DIR/runs/$(date -u '+ralph-run-%s.jsonl')"
  OUTPUT=$(run_codex "$prompt" "$run_file")
  
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
