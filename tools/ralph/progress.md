## Codebase Patterns
- `backlog/config.yml` status order is runtime queue precedence for review-flow stories; keep `Review` between `In Progress` and `Review Failed`, and lock it with a focused shell test.

--- 

# Ralph Progress Log
## 2026-04-17 00:13:33 CEST - US-007
- Added `Review` to `backlog/config.yml` status order between `In Progress` and `Review Failed`
- Added focused shell regression at `tests/backlog-config.sh`
- Files changed: `backlog/config.yml`, `tests/backlog-config.sh`, `tools/ralph/prd.json`, `tools/ralph/progress.md`, `AGENTS.md`
- **Learnings for future iterations:**
  - Runtime review-flow plan uses `backlog/config.yml` status order as cross-status queue precedence, so config order is behavior, not documentation
  - Small config-only stories still fit repo test style best as plain shell checks under `tests/`
  - Clean worktree on `ralph/runtime-review-flow` had to start from committed queue-review-flow branch state, because bare `main` lacked `/tools/ralph` task scaffold
---
