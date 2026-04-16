---
title: Ralph Runtime Metadata and Completion Redesign
type: note
permalink: ralph-backlog/specs/ralph-runtime-metadata-and-completion-redesign
tags:
- ralph
- backlog
- runtime
- spec
- codex
---

# Ralph Runtime Metadata and Completion Redesign

This note captures approved follow-up plan for `ralph.sh` after the shell audit and user clarifications. It intentionally keeps task-level implementation guidance usable, but narrows what that guidance can control: task text should guide implementation of the assigned work, not override Ralph's runtime orchestration rules. Useful future searches this note should answer: "how should ralph store codex session id", "does ralph still need promise complete", and "should ralph assign before in progress".

The redesign changes four important parts of the backlog-driven loop. First, assignee should identify only the agent, while resumable session state moves to a dedicated `session_id:<id>` label. Second, completion should come from backlog state and runtime JSONL outcomes, not from worker output markers like `<promise>COMPLETE</promise>`. Third, claim flow should visibly happen as assign first, then `In Progress`. Fourth, prompt construction should preserve task instructions for implementation while explicitly preventing task content from changing task selection, status transitions, sandbox, or approval behavior.

## Introduction / Overview

Refine Ralph runtime metadata and completion handling so task instructions remain useful but operational state becomes simpler and more reliable. The current design overloads assignee with both agent identity and resumable session id, depends on a worker-emitted completion marker for final success, and claims tasks in an order the user wants changed. This redesign keeps Backlog as the source of truth while moving runtime-only state into dedicated metadata and making script-controlled completion fully script-controlled.

## Goals

- Keep task instructions authoritative for task scope and implementation guidance.
- Make backlog state, not worker prose, determine whether the loop is complete.
- Store assignee as agent identity only and move session id to `session_id:<id>` label metadata.
- Change claim flow to assign first, then set status to `In Progress`.
- Preserve resume support and add migration tolerance for legacy `codex@<session_id>` tasks.

## User Stories

### US-001: Store worker session state in labels
**Description:** As Ralph runtime, I want resumable session state stored in a `session_id:<id>` label so assignee remains human-readable and operational metadata has one clear home.

**Acceptance Criteria:**
- [ ] Fresh worker run writes assignee as `codex` only.
- [ ] Fresh worker run persists exactly one `session_id:<id>` label after the first `thread.started` event.
- [ ] Resume path reads session id from task labels before launching `codex exec resume`.
- [ ] Legacy tasks that still use `codex@<session_id>` remain readable during migration and are rewritten to canonical metadata when touched.
- [ ] `bash tests/ralph-runtime.sh` passes.

### US-002: Claim tasks as assign, then in progress
**Description:** As a backlog operator, I want Ralph to claim work by assigning the agent first and then setting `In Progress` so visible task ownership matches the intended workflow.

**Acceptance Criteria:**
- [ ] Task claim flow writes assignee before setting status to `In Progress`.
- [ ] Fresh-start failure before session capture rolls the task back to `To Do`.
- [ ] Fresh-start failure before session capture does not leave stale `session_id:` label metadata behind.
- [ ] `bash tests/ralph-runtime.sh` passes.

### US-003: Derive completion from backlog state
**Description:** As Ralph runtime, I want loop completion decided from task state and runtime outcome events so workers do not need to emit `<promise>COMPLETE</promise>`.

**Acceptance Criteria:**
- [ ] `--verify none` marks successful tasks `Done`.
- [ ] Verifier pass marks task `Done` without requiring `<promise>COMPLETE</promise>` in worker output.
- [ ] After the last eligible task is completed, Ralph exits successfully by checking backlog state directly.
- [ ] Worker and verifier still use JSONL outcome events such as `turn.completed` and `turn.failed` to determine runtime success or failure.
- [ ] `bash tests/ralph-runtime.sh` passes.

### US-004: Keep task instructions usable with scoped trust
**Description:** As a Ralph operator, I want task instructions to remain usable for implementation while ensuring Ralph runtime rules cannot be overridden by task text.

**Acceptance Criteria:**
- [ ] Worker and verifier prompts place Ralph runtime rules before the assigned task payload.
- [ ] Prompt text explicitly says task content is authoritative for task scope, acceptance criteria, implementation plan, references, and task-specific guidance.
- [ ] Prompt text explicitly says task content must not override task selection, status transitions, sandbox, or approval behavior.
- [ ] Prompt regression tests cover the new prompt contract.

### US-005: Align docs and regression tests with the new metadata model
**Description:** As a future maintainer, I want docs, notes, and shell tests to describe the same runtime contract that Ralph actually uses.

**Acceptance Criteria:**
- [ ] Runtime shell tests assert assignee `codex` and session label `session_id:<id>` instead of `codex@<session_id>`.
- [ ] AGENTS guidance and relevant Basic Memory notes stop prescribing session ids inside assignee for the new design.
- [ ] Notes or docs that describe completion markers reflect that Ralph now verifies completion on its own.
- [ ] `bash tests/ralph-runtime.sh` passes.

## Functional Requirements

- FR-1: `ralph.sh` must store the worker assignee as the agent name only.
- FR-2: `ralph.sh` must persist resumable worker session state in a label formatted exactly as `session_id:<id>`.
- FR-3: `ralph.sh` must resume an existing worker session from `session_id:<id>` label metadata when present.
- FR-4: `ralph.sh` must continue reading legacy `codex@<session_id>` assignee values during migration.
- FR-5: `ralph.sh` must claim tasks by writing assignee first and status second.
- FR-6: `ralph.sh` must mark successful tasks `Done` even when verification mode is `none`.
- FR-7: `ralph.sh` must determine overall loop completion by querying backlog state directly rather than requiring worker output markers.
- FR-8: Worker and verifier prompts must preserve task implementation guidance while reserving orchestration authority for Ralph.
- FR-9: Shell regression tests must cover the new session metadata model, claim order, backlog-driven completion, and prompt contract.

## Non-Goals

- Do not remove implementation plans or other useful instructions from task content.
- Do not add new task statuses beyond `To Do`, `In Progress`, `Review Failed`, and `Done`.
- Do not introduce new verification modes beyond `none`, `same-session`, and `new-session`.
- Do not change dependency-aware task selection or forced sequence behavior outside what is needed for backlog-driven completion checks.

## Design Considerations

- Task text should stay rich enough for Codex to implement the assigned task without losing implementation plans, AC, DoD, references, or docs.
- Prompt structure should make the trust boundary obvious: task text controls implementation of the assigned task, while Ralph controls runtime orchestration.
- Visible backlog metadata should remain easy for humans to inspect during a live run.

## Technical Considerations

- The current live `backlog task --plain` output omits a `Labels:` section when labels are empty, so label parsing should tolerate missing label lines.
- Updating touched tasks to canonical metadata reduces long-term dual-format support even if backward-read compatibility is kept temporarily.
- Completion checks should use backlog state after status transitions so final-task success does not depend on worker self-reporting.
- Prompt tests should verify both presence of scoped-trust instructions and absence of stale `<promise>COMPLETE</promise>` dependency language.

## Success Metrics

- A fresh worker run can be resumed later using `session_id:<id>` label metadata.
- Final task completion succeeds without any worker-emitted completion marker.
- A failed fresh launch does not strand tasks in `In Progress` without usable resume metadata.
- Shell regression tests describe and enforce the same metadata contract the runtime uses.

## Open Questions

- Confirm exact plain-output formatting when task labels are non-empty and keep the parser aligned with real Backlog CLI output.

## Observations
- [decision] Task text remains authoritative for task scope and implementation guidance, but not for Ralph runtime control #prompt #scope
- [decision] Assignee should store only the agent name; worker session id moves to `session_id:<id>` label metadata #session #metadata
- [decision] Ralph no longer depends on `<promise>COMPLETE</promise>` from agents to determine loop completion #completion #runtime
- [decision] Task claim order should be assign first and then set status to `In Progress` #workflow
- [fact] Current `backlog task --plain` output omits a `Labels:` section when labels are empty #backlog #cli
- [migration] Legacy `codex@<session_id>` assignee values need backward-read compatibility during transition #compatibility #migration

## Relations
- extends [[Ralph Backlog Loop Design Spec]]
- extends [[Ralph Backlog Loop Design Decisions]]
- relates_to [[Ralph Shell Audit Findings]]
- relates_to [[Ralph Shell Runtime Tests]]