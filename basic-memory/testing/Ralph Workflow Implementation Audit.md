---
title: Ralph Workflow Implementation Audit
type: note
permalink: ralph-backlog/testing/ralph-workflow-implementation-audit
tags:
- ralph
- workflow
- audit
- shell
- codex
---

# Ralph Workflow Implementation Audit

This note captures how the current root `ralph.sh` implements the intended backlog-driven Ralph workflow, with emphasis on gaps between shell-enforced behavior and prompt-only behavior. Useful future searches this note should answer: "how does ralph.sh implement backlog workflow", "which Ralph workflow steps are only prompt-driven", and "what extra runtime behavior does ralph.sh add beyond spec".

The current script does implement the core backlog loop: select task, load `--plain` task text, claim task, start or resume Codex, persist `session_id:<id>` metadata, optionally verify, then mark `Done` or `Review Failed`. It also no longer depends on worker-emitted `<promise>COMPLETE</promise>` for overall loop completion; completion comes from backlog state via eligible-work checks.

The biggest drift is that worker task-shaping steps are not shell-enforced. Writing implementation plan, refining acceptance criteria or definition-of-done, checking checklist items, and writing final summary all depend on `prompt-codex.md`, not on `ralph.sh` validating the task afterward. The verifier marker is also only partially enforced: the prompt requires the marker on the first non-empty line, but the shell accepts the marker anywhere in output.

Another important drift is prompt trust boundary. The redesign says backlog task content should remain authoritative for task scope while not overriding runtime orchestration rules. The shell currently prepends raw task text before both worker and verifier prompt templates, so task content gets higher prompt position than the immutable instructions. Combined with defaults `RALPH_SANDBOX=danger-full-access` and `RALPH_APPROVAL_POLICY=never`, this keeps prompt-injection risk high.

The script also adds several runtime behaviors not called out in the basic workflow summary: environment-based Codex configuration, JSONL run logs under `runs/`, `mktemp`-created last-message files under `TMPDIR`, and fail-fast CLI validation for sequence items and verify mode.

## Observations
- [implemented] `ralph.sh` selects dependency-ready backlog tasks from `To Do`, or from `Review Failed` first when `--retry-review-failed` is enabled #selection
- [implemented] Forced `--sequence` and `--sequence-file` paths are validated up front for task existence and override normal selection by iteration index #sequence
- [implemented] Fresh-task claim flow assigns `codex` before setting `In Progress`, but resumed-session claim collapses assignee, status, and label update into one metadata edit #claim
- [implemented] Fresh-session metadata is persisted as label `session_id:<id>` after parsing `thread.started` from Codex JSONL logs, with backward-read compatibility for legacy `codex@<session_id>` assignees #session
- [gap] Worker responsibilities such as writing implementation plan, refining AC/DoD, checking items, and writing final summary are prompt-driven and not validated by shell after worker completion #worker #prompt
- [gap] Verifier output parsing accepts `<verification>PASS</verification>` or `<verification>FAIL</verification>` anywhere in output, not specifically on first non-empty line as prompt requires #verification
- [implemented] Successful completion with `--verify none` now marks task `Done` directly #status
- [implemented] Overall loop completion now depends on backlog eligibility checks, not on worker `<promise>COMPLETE</promise>` output #completion
- [drift] Worker prompt still tells Codex to emit `<promise>COMPLETE</promise>` when every backlog task is complete, but shell ignores that marker entirely #prompt #completion
- [risk] Raw backlog task text is prepended before worker and verifier instructions while Codex defaults to `danger-full-access` sandbox and `never` approval #security #prompt-injection
- [extra] Runtime behavior includes env-configurable model, reasoning, sandbox, approval policy, JSONL run logs, and `mktemp`-created last-message files that are cleaned up before `run_codex` returns #runtime

## Relations
- relates_to [[Ralph Backlog Loop Design Spec]]
- relates_to [[Ralph Runtime Metadata and Completion Redesign]]
- relates_to [[Ralph Shell Audit Findings]]
- relates_to [[Ralph Shell Runtime Tests]]
