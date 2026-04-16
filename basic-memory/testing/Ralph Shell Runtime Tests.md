---
title: Ralph Shell Runtime Tests
type: note
permalink: ralph-backlog/testing/ralph-shell-runtime-tests
tags:
- testing
- shell
---

# Ralph Shell Runtime Tests

When changing `ralph.sh`, keep runtime verification at shell level instead of invoking real Codex. The reliable pattern is a temporary fixture directory that copies `ralph.sh` plus prompt input, prepends a `bin/` folder to `PATH`, and provides tiny mock executables for `codex` plus fixture-local wrappers for commands whose usage you want to assert.

This lets tests verify CLI behavior, runtime control flow, and required-command boundaries without network access or real agent sessions. A useful guard is to omit `jq` from the fixture `PATH` and assert Ralph fails fast, because Codex JSONL parsing now depends on `jq` rather than shell regexes.

Likely future searches this note should answer: "how to test ralph.sh without real codex", "why does ralph runtime test remove jq", and "where are shell tests for codex-only loop".

## Observations
- [pattern] To prove pre-launch revalidation, use per-read task fixtures like `mock-backlog/task-1.show-2.txt`; this lets one ordered-list candidate become unrunnable between selection and worker launch without custom mock code per test #selection #testing
- [guard] Repeating the same task in `--sequence task-1,task-1` should now fail fast after the first successful iteration, because forced tasks are reloaded and must still be runnable before Codex starts #sequence #testing
- [pattern] Sequence-mode validation should fail before Codex starts for both `--sequence` and `--sequence-file`, so shell regressions should assert no mocked Codex stdin file exists on missing-task errors #sequence #testing

- [pattern] Parse `thread.started`, `turn.completed`, and `turn.failed` from `codex exec --json` logs with `jq`; shell tests should model those events explicitly and can wrap fixture-local `jq` to prove the filter path #codex #jsonl #testing
- [pattern] Last-message capture should use `mktemp` under `TMPDIR`; shell tests can wrap fixture-local `mktemp` to assert the chosen output path and that cleanup happens before the script returns #temp-files #testing
- [guard] Removing `sleep` from fixture `PATH` is a good regression check that Ralph no longer pauses between successful iterations #timing #testing

- [pattern] Fresh-session runtime tests should feed mocked `codex exec --json` output with a `thread.started` event, then assert Ralph persists assignee `codex` plus label `session_id:<thread_id>` after launch and transitions successful runs to `Done` unless more eligible work remains #backlog #session #testing
- [guard] Resume tests should use `Labels: session_id:<id>` only; legacy `Assignee: codex@<id>` fixtures should now fail rather than auto-migrate #backlog #session #testing
- [reason] Reloading `backlog task <id> --plain` after metadata edits keeps worker prompt text aligned with current assignee and status #backlog #prompt

- [pattern] `ralph.sh` regression tests can run as plain shell scripts under `tests/` with `bash tests/ralph-runtime.sh` #ralph #testing
- [pattern] Mock external CLIs by prepending fixture-local executables to `PATH` instead of patching global environment #shell #mocking
- [guard] Leaving `jq` out of fixture `PATH` should fail Ralph at required-command startup, because run-log parsing now depends on `jq` #jsonl #shell
- [rule] Runtime tests for Ralph should never invoke real `codex`; use a mock boundary and assert on process exit/output instead #codex #testing
- [pattern] Backlog-driven runtime tests should mock both `backlog task list --plain` and `backlog task <id> --plain`, then assert Codex stdin contains selected task text #backlog #testing
- [gotcha] Missing `backlog task <id> --plain` lookups may surface as text output rather than a trustworthy nonzero exit, so runtime code should validate task detail shape before treating lookup as success #backlog #cli

- [pattern] Prompt migrations should be regression-tested through mocked Codex stdin, asserting required worker instructions are present and stale `prd.json` or task-selection text is absent #prompt #testing
- [reason] `ralph.sh` prepends assigned task text before `prompt-codex.md`, so stdin assertions catch both prompt drift and wrapper drift in one shell-level test #prompt #shell

- [pattern] Fresh-task claim flow should use one `backlog task edit -s "In Progress" -a codex` call; keep the later `-l session_id:<id>` write separate because the session only exists after `thread.started` #backlog #workflow #testing
- [pattern] Automatic selection should skip tasks whose assignee is not empty and not listed in `config.yaml` `selection.allowed_assignees`, even when those tasks appear earlier in ordered backlog output #backlog #config #testing
- [pattern] If a fresh worker launch fails before Ralph captures `thread.started`, runtime should roll the task back to `To Do` and clear both assignee and `session_id:` label metadata; shell regressions should cover both missing-session-id and failed-start paths #backlog #rollback #session #testing
- [gotcha] Shell backlog mocks need to treat empty assignee and empty label edits as field removal so rollback assertions match real task metadata cleanup instead of leaving blank placeholder lines #mocking #testing #backlog
- [pattern] When runtime startup depends on repo-root `config.yaml`, shell fixtures should copy that file into temp workspace so config load path matches real repo layout #config #testing
- [pattern] Wrap fixture `python3` when you need to prove `config.yaml` loads before worker launch; capture args and stdin instead of invoking real agents #python #config #testing

## Relations
- relates_to [[Ralph Backlog Loop Design Spec]]
- relates_to [[Ralph Backlog Loop Design Decisions]]
- relates_to [[Ralph Agent Instructions]]
- [pattern] Verification runs should use a verifier-specific prompt and return `<verification>PASS</verification>` or `<verification>FAIL</verification>` through Codex last-message output so shell orchestration can distinguish review rejection from runtime failure #verification #prompt
- [pattern] `--verify same-session` should resume the worker session for verification, while `--verify new-session` should start a fresh Codex session and parse its own `thread.started` id #verification #session
- [pattern] When `ralph.sh` selects from more than one backlog status, shell fixtures should provide separate mocked `backlog task list -s "<status>" --sort priority --plain` outputs for each status so tests exercise real selection order instead of a shared list shortcut #backlog #testing #status

- [gotcha] `backlog task --plain` omits the `Labels:` line when a task has no labels, so shell parsers and fixtures must tolerate missing label metadata on fresh tasks #backlog #labels #testing
- [gotcha] Backlog-driven completion checks use fresh `backlog task list -s ... --plain` state after status edits, so shell mocks must update task-list fixtures when tasks move to `Done` or `Review Failed`; stale lists make Ralph think work still remains #backlog #testing #completion
- [guard] Completion checks that decide whether Ralph has finished all eligible work must mirror dependency filtering from selection; listed `To Do` or retryable `Review Failed` tasks do not count as remaining eligible work unless `dependencies_satisfied` passes #completion #dependencies #testing
