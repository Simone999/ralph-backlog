# Codebase Patterns
- Runtime session metadata now uses assignee `codex` plus label `session_id:<id>`; shell parsers should read `Labels:` first and only fall back to legacy `codex@<session_id>` assignees while migrating touched tasks.
- `backlog task --plain` omits the `Labels:` line when a task has no labels, so runtime parsing and test fixtures must tolerate that field being absent.

# Ralph Progress Log
Started: Thu Apr 16 14:21:12 CEST 2026
---

## 2026-04-16 14:27:15 CEST - US-001
- Implemented canonical session metadata in `ralph.sh`: Ralph now reads resume state from `Labels: session_id:<id>`, falls back to legacy `codex@<session_id>` assignees during migration, and rewrites touched tasks to assignee `codex` plus the session label.
- Expanded `tests/ralph-runtime.sh` to model backlog label edits, assert fresh-session label persistence, verify resume-from-label behavior, and cover legacy assignee migration to canonical metadata.
- Updated reusable runtime guidance in `AGENTS.md` for label-based session storage and missing `Labels:` lines in plain backlog output.
- Files changed: `ralph.sh`, `tests/ralph-runtime.sh`, `AGENTS.md`, `tools/ralph/prd.json`, `tools/ralph/progress.md`
- **Learnings for future iterations:**
  - Patterns discovered: Backlog session metadata should be normalized through `-a codex -l session_id:<id>` so resume state has one home and assignee stays human-readable.
  - Gotchas encountered: `backlog task --plain` has no `Labels:` line when empty, so shell parsers must not treat missing labels as malformed task output.
  - Useful context: keeping legacy `codex@<session_id>` fallback in parser lets Ralph rewrite old tasks opportunistically without breaking resume flow.
---
