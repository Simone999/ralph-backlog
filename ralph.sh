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
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
        shift
      else
        die "usage: ./ralph.sh [--tool codex] [max_iterations]"
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

require_cmd cat codex date grep mkdir seq sleep


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
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  prompt="$(cat "$SCRIPT_DIR/prompt-codex.md")"
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
