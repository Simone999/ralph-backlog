# Codebase Patterns
- Runtime session metadata now uses assignee `codex` plus label `session_id:<id>`; shell parsers should read `Labels:` first and only fall back to legacy `codex@<session_id>` assignees while migrating touched tasks.
- `backlog task --plain` omits the `Labels:` line when a task has no labels, so runtime parsing and test fixtures must tolerate that field being absent.
- Fresh task claims should write assignee `codex` before status `In Progress`; if startup fails before `thread.started`, roll task back to `To Do` and clear assignee plus `session_id:` labels.

# Ralph Progress Log
Started: Thu Apr 16 14:21:12 CEST 2026
---

## 2026-04-16 14:27:15 CEST - US-001
- Implemented canonical session metadata in `ralph.sh`: Ralph now reads resume state from `Labels: session_id:<id>`, falls back to legacy `codex@<session_id>` assignees during migration, and rewrites touched tasks to assignee `codex` plus the session label.
- Expanded `tests/ralph-runtime.sh` to model backlog label edits, assert fresh-session label persistence, verify resume-from-label behavior, and cover legacy assignee migration to canonical metadata.
- Updated reusable runtime guidance in `AGENTS.md` for label-based session storage and missing `Labels:` lines in plain backlog output.
- Files changed: `ralph.sh`, `tests/ralph-runtime.sh`, `AGENTS.md`, `basic-memory/testing/Ralph Shell Runtime Tests.md`, `tools/ralph/prd.json`, `tools/ralph/progress.md`
- **Learnings for future iterations:**
  - Patterns discovered: Backlog session metadata should be normalized through `-a codex -l session_id:<id>` so resume state has one home and assignee stays human-readable.
  - Gotchas encountered: `backlog task --plain` has no `Labels:` line when empty, so shell parsers must not treat missing labels as malformed task output.
  - Useful context: keeping legacy `codex@<session_id>` fallback in parser lets Ralph rewrite old tasks opportunistically without breaking resume flow.
---

## 2026-04-16 14:39:00 CEST - US-002
- Implemented safe fresh-task claim flow in `ralph.sh`: fresh runs now assign `codex` first, then move task to `In Progress`, and rollback to `To Do` with cleared assignee/labels if worker startup fails before session capture.
- Expanded `tests/ralph-runtime.sh` to log backlog edit order, assert assign-before-status behavior, and verify rollback for both failed worker start and missing `thread.started` session capture.
- Updated reusable runtime guidance in `AGENTS.md`, Codebase Patterns, and Basic Memory runtime test notes for pre-session-capture rollback behavior.
- Files changed: `ralph.sh`, `tests/ralph-runtime.sh`, `AGENTS.md`, `tools/ralph/prd.json`, `tools/ralph/progress.md`
- **Learnings for future iterations:**
  - Patterns discovered: Fresh backlog claims should be two edits, assignee first and status second, so ownership becomes visible before active-work state.
  - Gotchas encountered: pre-session-capture failures need explicit rollback because otherwise fresh tasks stay stranded `In Progress` with stale runtime ownership.
  - Useful context: shell backlog mocks must treat empty assignee and label writes as field removal to model rollback cleanup correctly.
---
