#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [--tool codex|amp|claude] [max_iterations]

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
        die "usage: ./ralph.sh [--tool codex|amp|claude] [max_iterations]"
      fi
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "codex" && "$TOOL" != "amp" && "$TOOL" != "claude" ]]; then
  die "Invalid tool '$TOOL'. Must be 'codex', 'amp', or 'claude'."
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.md"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

RALPH_MODEL="${RALPH_MODEL:-gpt-5.4}"
RALPH_REASONING="${RALPH_REASONING:-high}"
RALPH_SANDBOX="${RALPH_SANDBOX:-danger-full-access}"
RALPH_APPROVAL_POLICY="${RALPH_APPROVAL_POLICY:-never}"

require_cmd codex jq find sed date tee


CODEX_BASE_CMD=(
  codex
  -a "$RALPH_APPROVAL_POLICY"
  exec
  --color never
  -m "$RALPH_MODEL"
  -c "model_reasoning_effort=\"$RALPH_REASONING\""
  -s "$RALPH_SANDBOX"
)

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"
    
    log "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"
    
    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

log "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

# Run the selected tool with the ralph prompt
  if [[ "$TOOL" == "amp" ]]; then
    OUTPUT=$(cat "$SCRIPT_DIR/prompt.md" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
  elif [[ "$TOOL" == "claude" ]]; then
    # Claude Code: use --dangerously-skip-permissions for autonomous operation, --print for output
    OUTPUT=$(claude --dangerously-skip-permissions --print < "$SCRIPT_DIR/CLAUDE.md" 2>&1 | tee /dev/stderr) || true
  elif [[ "$TOOL" == "codex" ]]; then
    prompt=$(sed \
      -e "s|\[PRD\]|$PRD_FILE|g" \
      -e "s|\[PROGRESS\]|$PROGRESS_FILE|g" \
      "$SCRIPT_DIR/prompt-codex.md")
    
    run_file="$SCRIPT_DIR/runs/$(date -u '+ralph-run-%s.jsonl')"
    OUTPUT=$(run_codex "$prompt" "$run_file")
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
log "Check $PROGRESS_FILE for status."
exit 1
