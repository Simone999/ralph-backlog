---
title: Ralph Shell Runtime Tests
type: note
permalink: ralph-backlog/testing/ralph-shell-runtime-tests
tags:
- testing
- shell
---

# Ralph Shell Runtime Tests

When changing `ralph.sh`, keep runtime verification at shell level instead of invoking real Codex. The reliable pattern is a temporary fixture directory that copies `ralph.sh` plus prompt input, prepends a `bin/` folder to `PATH`, and provides tiny mock executables for `codex` and `sleep`.

This lets tests verify CLI behavior, runtime control flow, and required-command boundaries without network access or real agent sessions. A useful guard for the codex-only migration is to omit `jq` from the fixture `PATH`; if `ralph.sh` still requires or executes `jq`, the test fails immediately.

Likely future searches this note should answer: "how to test ralph.sh without real codex", "why does ralph runtime test remove jq", and "where are shell tests for codex-only loop".

## Observations
- [pattern] To prove fresh-session metadata round-trips into a later resume, force the same task twice with `--sequence task-1,task-1`; assert first mocked Codex call emits `thread.started` and second call uses `exec resume <session_id>` #session #testing
- [pattern] Sequence-mode validation should fail before Codex starts for both `--sequence` and `--sequence-file`, so shell regressions should assert no mocked Codex stdin file exists on missing-task errors #sequence #testing

- [pattern] Treat `turn.completed` as worker success and `turn.failed` as worker failure when consuming `codex exec --json` output; shell tests should model both events explicitly #codex #jsonl #testing
- [gotcha] Codex JSONL logs may end without a trailing newline, so shell parsers must read with `while IFS= read -r line || [[ -n "$line" ]]` or the final outcome event can be missed #shell #jsonl

- [pattern] Fresh-session runtime tests should feed mocked `codex exec --json` output with a `thread.started` event, then assert Ralph persists assignee `codex` plus label `session_id:<thread_id>` after launch while leaving the task `In Progress` throughout #backlog #session #testing
- [reason] Reloading `backlog task <id> --plain` after metadata edits keeps worker prompt text aligned with current assignee and status #backlog #prompt

- [pattern] `ralph.sh` regression tests can run as plain shell scripts under `tests/` with `bash tests/ralph-runtime.sh` #ralph #testing
- [pattern] Mock external CLIs by prepending fixture-local executables to `PATH` instead of patching global environment #shell #mocking
- [guard] Leaving `jq` out of fixture `PATH` catches accidental fallback to old PRD-driven runtime logic #prd #shell
- [rule] Runtime tests for Ralph should never invoke real `codex`; use a mock boundary and assert on process exit/output instead #codex #testing
- [pattern] Backlog-driven runtime tests should mock both `backlog task list --plain` and `backlog task <id> --plain`, then assert Codex stdin contains selected task text #backlog #testing
- [gotcha] Missing `backlog task <id> --plain` lookups may surface as text output rather than a trustworthy nonzero exit, so runtime code should validate task detail shape before treating lookup as success #backlog #cli

- [pattern] Prompt migrations should be regression-tested through mocked Codex stdin, asserting required worker instructions are present and stale `prd.json` or task-selection text is absent #prompt #testing
- [reason] `ralph.sh` prepends assigned task text before `prompt-codex.md`, so stdin assertions catch both prompt drift and wrapper drift in one shell-level test #prompt #shell

## Relations
- relates_to [[Ralph Backlog Loop Design Spec]]
- relates_to [[Ralph Backlog Loop Design Decisions]]
- relates_to [[Ralph Agent Instructions]]
- [pattern] Verification runs should use a verifier-specific prompt and return `<verification>PASS</verification>` or `<verification>FAIL</verification>` through Codex last-message output so shell orchestration can distinguish review rejection from runtime failure #verification #prompt
- [pattern] `--verify same-session` should resume the worker session for verification, while `--verify new-session` should start a fresh Codex session and parse its own `thread.started` id #verification #session
- [pattern] When `ralph.sh` selects from more than one backlog status, shell fixtures should provide separate mocked `backlog task list -s "<status>" --sort priority --plain` outputs for each status so tests exercise real selection order instead of a shared list shortcut #backlog #testing #status

- [gotcha] `backlog task --plain` omits the `Labels:` line when a task has no labels, so shell parsers and fixtures must tolerate missing label metadata on fresh tasks #backlog #labels #testing
