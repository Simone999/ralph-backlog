---
title: Ralph Backlog Loop Design Spec
type: note
permalink: ralph-annotator/specs/ralph-backlog-loop-design-spec
tags:
- ralph
- backlog
- design
- spec
---

# Ralph Backlog Loop Design Spec

This note captures the approved design for moving Ralph from PRD-driven story selection to Backlog.md-driven task orchestration.

Ralph should use Backlog.md as the only task state. The script owns orchestration. The coding agent no longer chooses work. Instead, the script selects a task, passes the plain task text to Codex, and manages status transitions around implementation and optional verification.

## Goal

Make Ralph backlog-driven, script-driven, and Codex-only at runtime while keeping a future-ready CLI shape.

## Scope

- Keep `--tool`, but allow only `codex` for now
- Remove Amp and Claude runtime paths
- Do not use `prd.json` for loop state
- Assume backlog already contains all tasks needed by the run
- Fail fast if a forced sequence references a missing task

## Source Of Truth

Backlog is the only task state. Ralph should not read `prd.json` to select work. Task status, assignee, acceptance criteria, definition of done, notes, review notes, and final summary all live in Backlog.

Task text should be passed to Codex from the script with `backlog task <task_id> --plain`.

## Selection Modes

Ralph supports two selection modes.

### Dependency-aware mode

This is the default mode. Ralph picks the highest-priority task in `To Do` whose dependencies are satisfied.

### User-provided sequence mode

This is an override mode. The user can force task order from CLI input or file input. Sequence entries must exist in backlog. If one is missing, Ralph stops immediately.

### Mixed behavior

Normal behavior is dependency-aware. Sequence input overrides normal selection when provided.

## Status Model

Use these statuses:

- `To Do`
- `In Progress`
- `Review Failed`
- `Done`

Meaning:

- `To Do`: normal eligible work
- `In Progress`: active Codex run owns the task
- `Review Failed`: implementation happened, but verification found gaps
- `Done`: task is complete

### Review-failed retry flag

Add `--retry-review-failed`.

When the flag is off, Ralph auto-selects only `To Do`, and `Review Failed` tasks run only when forced by sequence.

When the flag is on, `Review Failed` tasks re-enter the eligible pool and should be preferred ahead of fresh `To Do` work.

## Assignee And Resume State

Store resumable agent identity in backlog assignee using `<agent>@<session_id>`.

Example: `codex@123456`

This lets Ralph recover resumable Codex context directly from backlog metadata. If Ralph starts fresh work, it writes a new assignee value. If Ralph resumes same Codex session, it reuses the session id from assignee.

## Iteration Workflow

One Ralph iteration should do this:

1. Script selects next task
2. Script loads task text with `backlog task <task_id> --plain`
3. Script starts or resumes Codex session for that task
4. Script sets task status to `In Progress`
5. Script stores assignee as `<agent>@<session_id>`
6. Codex enters plan mode and writes implementation plan into task
7. Codex reviews AC and DoD, and may create, edit, or delete weak items
8. Codex implements task
9. Codex checks AC and DoD only when truly done
10. Codex writes final summary into task
11. Optional verifier pass runs
12. Script marks task `Done` or `Review Failed`
13. Loop continues to next task

## Codex Worker Contract

Worker Codex gets one assigned task, not a task list.

Worker must:

1. Read passed backlog task text
2. Add implementation plan to task before coding
3. Review and improve AC and DoD if needed
4. Implement the plan
5. Check AC and DoD as real work finishes
6. Add final summary to task
7. Return control to Ralph

Worker must not:

- choose next task
- inspect backlog board to self-assign work
- use `prd.json` for task selection

## Verification Pass

Verification is optional. Mode should be controlled by default setting plus CLI override.

Supported modes should be:

- `none`
- `same-session`
- `new-session`

`new-session` is the safer default because verifier gets fresh eyes.

If verification passes, script marks task `Done`.

If verification fails, script must:

1. append review notes to task
2. set status to `Review Failed`
3. preserve or rewrite assignee as `<agent>@<session_id>` so later iteration may resume useful context

## CLI Surface

Keep entrypoint as `ralph.sh`.

Keep `--tool`, but accept only `--tool codex` for now.

Add or keep flags like:

- `--sequence task-7,task-3`
- `--sequence-file path/to/order.txt`
- `--verify none|same-session|new-session`
- `--retry-review-failed`

Exact names can change, but behavior should stay as approved in this design.

## Script Structure

Keep `ralph.sh` as entrypoint, but split behavior into small helper functions so the script does not turn into soup.

Likely helpers:

- `require_cmds`
- `parse_args`
- `select_next_task`
- `select_from_sequence`
- `select_dependency_ready_task`
- `load_task_plain`
- `mark_in_progress`
- `run_codex_task_session`
- `run_codex_verification`
- `handle_verification_failure`
- `mark_done`
- `should_continue`

Helpers can stay inside `ralph.sh` or move to tiny sourced shell files. The choice should optimize readability and testability.

## Prompt Changes

The current Codex prompt must change.

Remove old behavior:

- read `prd.json`
- choose highest-priority story
- mark PRD story as passed

Add new behavior:

- task text comes from `backlog task <id> --plain`
- add implementation plan to backlog task
- refine AC and DoD before work when needed
- check AC and DoD only when truly done
- add final summary to backlog task

Need two prompt shapes:

- worker prompt
- verifier prompt

These can be separate files or one template with a mode switch.

## Failure Handling

Fail fast when:

- forced sequence references missing task
- backlog CLI missing
- selected task cannot load with `backlog task <id> --plain`
- task status update fails
- Codex launch or resume fails before work starts

Do not silently mark success. If worker ends without clear success signal, iteration fails.

If launch or setup fails before real work starts, the Ralph run fails.

If worker fails mid-task but session is resumable and useful, leaving task `In Progress` is acceptable. Otherwise script should fail loudly rather than hide broken state.

## Testing Strategy

Tests must never invoke real Codex.

All end-to-end and integration-style tests should use a mocked shell script that stands in for the Codex boundary.

The mock must cover:

- normal success
- implementation failure
- verification failure
- same-session verify path
- new-session verify path
- resume from assignee session id
- output and exit behavior expected by `ralph.sh`

Coverage should include:

- dependency-aware selection logic
- sequence override logic
- missing-task fail-fast behavior
- `--retry-review-failed` eligibility behavior
- assignee parse/format round-trip for `<agent>@<session_id>`
- prompt content no longer mentioning `prd.json` or agent-side task selection

## Non-Goals

- Creating backlog tasks during loop runtime
- Supporting Amp runtime execution
- Supporting Claude runtime execution
- Keeping PRD-driven task selection in parallel with backlog-driven mode

## Observations
- [decision] Backlog.md becomes the only source of truth for Ralph task state
- [decision] `ralph.sh` owns task selection and status transitions
- [decision] Codex receives a single assigned task through `backlog task <task_id> --plain`
- [decision] Codex writes implementation plan back into the task before coding
- [decision] Codex may refine acceptance criteria and definition of done before implementation
- [decision] Review failure moves task to `Review Failed`
- [decision] Resume state is stored in assignee using `<agent>@<session_id>`
- [decision] `--retry-review-failed` controls automatic re-elaboration of failed-review tasks
- [decision] Runtime support stays future-ready through `--tool`, but only `codex` is valid now
- [requirement] Tests must use a mocked Codex shell boundary and never invoke real Codex

## Relations
- relates_to [[Ralph Backlog Loop Design Decisions]]
- relates_to [[Ralph Agent Instructions]]
- relates_to [[Task Workflow]]