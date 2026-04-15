# Codebase Patterns
- Shell regressions for `ralph.sh` live in `tests/ralph-runtime.sh`; mock external CLIs through `PATH` and never invoke real `codex`.

---

# Progress Logs

## 2026-04-16 00:36:25 CEST - US-001
- Implemented codex-only runtime in `ralph.sh`: `--tool` now accepts only `codex`, Amp/Claude branches are removed, and script no longer reads or tracks `prd.json` state.
- Added `tests/ralph-runtime.sh` covering unsupported tool rejection plus one-iteration codex execution without `prd.json` or `jq`.
- Updated `AGENTS.md` runtime guidance to reflect codex-only behavior and document shell test harness location.
- Files changed: `ralph.sh`, `tests/ralph-runtime.sh`, `AGENTS.md`, `basic-memory/testing/Ralph Shell Runtime Tests.md`, `tools/ralph/prd.json`, `tools/ralph/progress.md`
- **Learnings for future iterations:**
  - Patterns discovered: use fixture-local `PATH` shims to mock `codex` and runtime dependencies in shell tests.
  - Gotchas encountered: omitting `jq` from fixture `PATH` is a good guard against accidental drift back to PRD-driven shell logic.
  - Useful context: `ralph.sh` currently sends raw `prompt-codex.md`; task-scoped prompt migration still belongs to later prompt-focused stories.
---
