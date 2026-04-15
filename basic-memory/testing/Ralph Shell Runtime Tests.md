---
title: Ralph Shell Runtime Tests
type: note
permalink: ralph-backlog/testing/ralph-shell-runtime-tests
tags:
- ralph
- testing
- shell
---

# Ralph Shell Runtime Tests

When changing `ralph.sh`, keep runtime verification at shell level instead of invoking real Codex. The reliable pattern is a temporary fixture directory that copies `ralph.sh` plus prompt input, prepends a `bin/` folder to `PATH`, and provides tiny mock executables for `codex` and `sleep`.

This lets tests verify CLI behavior, runtime control flow, and required-command boundaries without network access or real agent sessions. A useful guard for the codex-only migration is to omit `jq` from the fixture `PATH`; if `ralph.sh` still requires or executes `jq`, the test fails immediately.

Likely future searches this note should answer: "how to test ralph.sh without real codex", "why does ralph runtime test remove jq", and "where are shell tests for codex-only loop".

## Observations
- [pattern] `ralph.sh` regression tests can run as plain shell scripts under `tests/` with `bash tests/ralph-runtime.sh` #ralph #testing
- [pattern] Mock external CLIs by prepending fixture-local executables to `PATH` instead of patching global environment #shell #mocking
- [guard] Leaving `jq` out of fixture `PATH` catches accidental fallback to old PRD-driven runtime logic #prd #shell
- [rule] Runtime tests for Ralph should never invoke real `codex`; use a mock boundary and assert on process exit/output instead #codex #testing
- [pattern] Backlog-driven runtime tests should mock both `backlog task list --plain` and `backlog task <id> --plain`, then assert Codex stdin contains selected task text #backlog #testing
- [gotcha] Missing `backlog task <id> --plain` lookups may surface as text output rather than a trustworthy nonzero exit, so runtime code should validate task detail shape before treating lookup as success #backlog #cli

## Relations
- relates_to [[Ralph Backlog Loop Design Spec]]
- relates_to [[Ralph Backlog Loop Design Decisions]]
- relates_to [[Ralph Agent Instructions]]
