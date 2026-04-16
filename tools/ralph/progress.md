## Codebase Patterns
- `backlog/config.yml` status order is runtime queue precedence for review-flow stories; keep `Review` between `In Progress` and `Review Failed`, and lock it with a focused shell test.
- Root `config.yaml` drives Ralph runtime policy; shell regressions that touch runtime startup should copy that file into fixture and can wrap `python3` to prove config load happens before worker run.
- No-sequence selection should consume one ordered `backlog task list --sort priority --plain` result; shell fixtures should store that separately from status-specific task lists because completion checks still query `-s "<status>"`.

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
## 2026-04-17 01:06:33 CEST - US-008
- Added repo-root `config.yaml` with Ralph runtime defaults for allowed assignees and review policy
- Taught `ralph.sh` to load runtime config through `python3` + PyYAML before task selection or review work starts
- Expanded `tests/ralph-runtime.sh` with config defaults, missing-`python3`, and startup-load coverage
- Files changed: `config.yaml`, `ralph.sh`, `tests/ralph-runtime.sh`, `tools/ralph/prd.json`, `tools/ralph/progress.md`, `AGENTS.md`
- **Learnings for future iterations:**
  - Root `config.yaml` is Ralph-only runtime policy; keep it separate from Backlog project config in `backlog/config.yml`
  - Shell fixture must copy `config.yaml` when startup behavior depends on runtime policy
  - Wrapping `python3` inside fixture is clean way to prove config load timing without real network or agent calls
---
## 2026-04-17 01:14:19 CEST - US-009
- Switched no-sequence selection in `ralph.sh` from status-by-status scans to one ordered `backlog task list --sort priority --plain` pass, while keeping current candidate rules (`To Do`, plus `Review Failed` only when retry flag is set)
- Added selection regression coverage for ordered-list queue building and updated shell fixtures to distinguish ordered list output from status-specific task lists
- Files changed: `ralph.sh`, `tests/ralph-runtime.sh`, `tools/ralph/prd.json`, `tools/ralph/progress.md`, `AGENTS.md`
- **Learnings for future iterations:**
  - Queue order now comes from emitted backlog list order, not manual status precedence inside `ralph.sh`
  - Ordered-list selection fixtures need a separate `task-list-all` view; status-specific fixtures still matter for completion checks
  - `extract_task_status` must recognize `Review` even before runtime starts selecting that status, because ordered scans can encounter it while skipping non-runnable work
---
