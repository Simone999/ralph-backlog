---
title: Ralph Queue-Driven Review Flow Plan
type: note
permalink: ralph-backlog/plans/ralph-queue-driven-review-flow-plan
tags:
- ralph
- plan
- runtime
- review
- verifier
- backlog
---

# Ralph Queue-Driven Review Flow Plan

## Summary

Update Ralph from status-specific selection and prompt-only completion checks to one ordered backlog-list pass plus script-enforced gates.

Default no-sequence flow should read `backlog task list --sort priority --plain` once, preserve its emitted order, and then load task details only for candidates that are still valid: eligible status, unassigned or assigned to an allowed runner, and dependency-ready. Cross-status precedence should come from `backlog/config.yml` status order, which should be updated to `["To Do", "In Progress", "Review", "Review Failed", "Done"]`.

Worker completion should no longer rely on prompt compliance alone. After every worker turn, Ralph should run script-side task-state verification, auto-resume the worker with concrete remediation instructions when required fields/checks are missing, then move the task through `Review` and verifier pass/fix loop until it reaches `Done` or `Review Failed`.

## Key Changes

### Runtime policy and config
- Add repo-root `config.yaml` for Ralph-only static policy. Keep Backlog project config in `backlog/config.yml` untouched except for status list.
- Use this config shape:
  ```yaml
  selection:
    allowed_assignees:
      - codex
  review:
    no_review_terminal_status: done
    max_fix_attempts: 2
  ```
- Treat `selection.allowed_assignees` as exact assignee names Ralph may claim/resume. Non-sequence selection should accept tasks with empty assignee or assignee in that list. Forced sequence should still validate assignee eligibility and fail if task is not runnable by current runner.
- Parse `config.yaml` with `python3` + PyYAML. Add `python3` and `jq` to required commands.

### Selection and task lifecycle
- Replace status-by-status task selection with one ordered parse of `backlog task list --sort priority --plain`.
- Parse grouped plain output in emitted order. For each task id, load `backlog task <id> --plain` and keep only tasks whose current detail view is valid:
  - `To Do` always eligible
  - `Review` eligible only when review is enabled for this run
  - `Review Failed` eligible only with `--retry-review-failed`
  - `In Progress` only when explicitly forced by sequence and session label exists
  - assignee empty or in `selection.allowed_assignees`
  - dependencies all `Done`
- Before calling Codex, re-load the selected task and re-check status, assignee, and dependencies. If a non-sequence candidate became invalid, skip it and continue scanning. If a sequence task became invalid, fail fast.
- Change claim step to one atomic `backlog task edit` call that sets assignee and status together. Fresh claim should use `-a "$TOOL" -s "In Progress"`. Resumed claim should include the session label in the same edit.
- Remove all legacy `codex@<id>` parsing and migration logic. Session resume should come only from `Labels: session_id:<id>`.

### JSON handling, verifier contract, and temp files
- Replace manual JSONL parsing with `jq`:
  - first `thread.started.thread_id`
  - first `turn.failed.error`
  - presence of `turn.completed`
- Keep session id storage only in `session_id:<id>` label.
- Replace timestamp-based `/tmp/ralph-last-message-<epoch>.txt` with `mktemp`-created files and cleanup via `trap`.
- Remove iteration `sleep`.
- Add static verifier schema file and run verifier with `codex exec --output-schema <schema> -o <last_message_file>`.
- Change verifier prompt to require JSON only, matching this shape:
  ```json
  {
    "result": "pass|fail",
    "summary": "short summary",
    "issues": ["issue 1", "issue 2"]
  }
  ```
- Parse verifier result from the schema-validated last-message file with `jq`, not marker scraping.

### Script verification and fix loop
- Add script-side task-state verification after every worker turn and before any final status transition. Verify from `backlog task <id> --plain` that:
  - `Implementation Plan` section exists and is non-empty
  - `Final Summary` section exists and is non-empty
  - acceptance criteria are defined and all checked
  - definition-of-done items are defined and all checked
  - task still has expected assignee/session metadata
- If script verification fails, do not review or finish task yet. Resume the worker with a remediation prompt that includes the missing items list and current task plain output. Re-run worker completion checks, reload task, and re-run script verification. Retry up to `review.max_fix_attempts`.
- If review is enabled and script verification passes, move task to `Review` before verifier starts.
- If verifier fails, append verifier feedback to notes, move task back to `In Progress`, resume the same worker session with those review issues, then repeat worker completion -> script verification -> `Review` -> verifier. If same-session repair is impossible because session label is missing, fall back to a fresh worker fix session rather than stranding the task.
- If remediation attempts are exhausted at either script-verification or verifier stage, move task to `Review Failed` and preserve the session label for later retry.
- If review is disabled, terminal status comes from `review.no_review_terminal_status`:
  - `done` -> mark `Done`
  - `review` -> leave in `Review`
- Completion checks should treat `Review` tasks as remaining work only when review is enabled for that run. In no-review runs, queued `Review` tasks should not block successful exit.

## Interfaces

- New repo-root `config.yaml` with `selection.allowed_assignees`, `review.no_review_terminal_status`, `review.max_fix_attempts`.
- Updated `backlog/config.yml` statuses list includes `Review` so backlog-list order becomes runtime precedence source.
- New verifier JSON schema file for `codex exec --output-schema`.
- Updated `prompt-verifier.md` JSON-only contract.
- Updated `prompt-codex.md` remediation contract so resumed fix requests are explicit and `<promise>COMPLETE</promise>` language is removed.

## Test Plan

- Rewrite shell fixture selection tests to mock one full `backlog task list --sort priority --plain` output and assert Ralph follows emitted order, then filters by assignee and dependencies from task details.
- Add tests for:
  - unassigned task selected
  - allowed-assignee task selected
  - foreign-assignee task skipped
  - selected task becomes invalid before Codex call and is skipped or fails fast in sequence mode
  - atomic assign+status claim
  - fresh-session resume from `session_id:` only
  - no legacy `codex@...` support
  - `jq`-based JSONL parsing for thread id, `turn.failed`, and `turn.completed`
  - unique temp last-message file creation and cleanup
  - no `sleep` dependency
  - script-verification failure triggers same-session remediation and then passes
  - script-verification failure exhausts attempts and lands in `Review Failed`
  - verifier runs with `--output-schema`
  - verifier JSON `pass` reaches `Done`
  - verifier JSON `fail` triggers worker remediation loop
  - no-review mode with terminal `done`
  - no-review mode with terminal `review`
  - queued `Review` tasks are picked up later according to backlog list order when review is enabled
- Update docs/tests that currently encode legacy behavior: remove “runs without jq” expectation, remove legacy assignee migration tests, and align runtime docs/AGENTS notes with `Review` status and config-driven no-review behavior.

## Assumptions

- “Fix the issue” means fixing step-9 state transitions and completion handling so `Review`, `Done`, and `Review Failed` behave coherently under review-enabled and no-review runs.
- `backlog task list --sort priority --plain` emitted order is the intended source of truth for cross-status ordering once `backlog/config.yml` status order is updated.
- Root `config.yaml` is Ralph-specific and separate from Backlog’s own `backlog/config.yml`.
- PyYAML is available through `python3`, so adding a new YAML parser dependency is unnecessary.
