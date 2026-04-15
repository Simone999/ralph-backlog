# PRD: Ralph Backlog Loop

## Introduction

Ralph currently loops on `prd.json` stories and lets the agent choose work.
This feature moves Ralph to Backlog.md task state and script-owned orchestration.
`ralph.sh` should select the next task, pass the plain task text to Codex, let Codex plan and implement against that task, optionally verify the result, then move the task to the right final status.

This change also removes runtime support for Amp and Claude while keeping the `--tool` flag for future expansion.

## Goals

- Make Backlog.md the only source of truth for Ralph task state
- Move task selection from agent prompt into `ralph.sh`
- Support dependency-aware default selection and user-provided sequence override
- Support resumable Codex sessions through backlog assignee metadata
- Add optional post-implementation verification with `Review Failed` handling
- Replace old PRD-driven runtime docs and prompts with backlog-driven behavior
- Cover the orchestration with mock-based tests that never invoke real Codex

## User Stories

### US-001: Replace PRD-driven runtime with codex-only orchestration
**Description:** As a maintainer, I want `ralph.sh` to run only the Codex runtime path so that the loop behavior is smaller, clearer, and aligned with the new backlog-driven model.

**Acceptance Criteria:**
- [ ] `ralph.sh` keeps `--tool` parsing but accepts only `codex`
- [ ] Amp and Claude execution paths are removed from runtime behavior
- [ ] Runtime no longer depends on `prd.json` for task selection or completion tracking
- [ ] Failure message is clear when user passes unsupported tool value
- [ ] Relevant automated tests pass

### US-002: Select next backlog task in script
**Description:** As Ralph, I want the script to choose the next task from backlog so that the coding agent works only on explicitly assigned work.

**Acceptance Criteria:**
- [ ] Default mode picks the highest-priority dependency-ready task in `To Do`
- [ ] Sequence mode accepts explicit task order from CLI or file input
- [ ] Sequence mode fails fast if any referenced task is missing
- [ ] Task text passed to Codex comes from `backlog task <task_id> --plain`
- [ ] Relevant automated tests pass

### US-003: Track active Codex session in backlog metadata
**Description:** As Ralph, I want backlog metadata to carry resumable Codex identity so that future iterations can continue useful work without separate local state.

**Acceptance Criteria:**
- [ ] Active task assignee is stored as `<agent>@<session_id>`
- [ ] Fresh work writes a new `codex@<session_id>` assignee value
- [ ] Resume flow reads prior session id from assignee metadata
- [ ] Task status moves to `In Progress` before active implementation starts
- [ ] Relevant automated tests pass

### US-004: Update Codex worker prompt for task-scoped execution
**Description:** As a coding agent, I want a task-scoped prompt so that I plan, refine, implement, and summarize one assigned backlog task without choosing work myself.

**Acceptance Criteria:**
- [ ] Worker prompt no longer tells Codex to read `prd.json` or choose a story
- [ ] Worker prompt instructs Codex to add an implementation plan to the backlog task before coding
- [ ] Worker prompt allows Codex to create, edit, or delete weak AC and DoD items before implementation
- [ ] Worker prompt requires Codex to check AC and DoD only when truly complete
- [ ] Worker prompt requires Codex to add final summary to the task before returning
- [ ] Relevant automated tests pass

### US-005: Add optional verification pass and review-failed loop
**Description:** As Ralph, I want an optional verification pass after implementation so that tasks reach `Done` only when acceptance criteria and definition of done are really satisfied.

**Acceptance Criteria:**
- [ ] Script supports verification modes `none`, `same-session`, and `new-session`
- [ ] Verification pass uses a verifier-specific Codex prompt or equivalent mode switch
- [ ] On verification success, script moves task to `Done`
- [ ] On verification failure, script appends review notes and moves task to `Review Failed`
- [ ] Failed review preserves or rewrites assignee in `<agent>@<session_id>` form for future resume
- [ ] Relevant automated tests pass

### US-006: Support automatic re-elaboration of failed-review tasks
**Description:** As a maintainer, I want a retry flag for `Review Failed` tasks so that Ralph can either focus on fresh work or automatically return to failed reviews.

**Acceptance Criteria:**
- [ ] Script supports `--retry-review-failed`
- [ ] Without the flag, auto-selection considers only `To Do` tasks
- [ ] With the flag, `Review Failed` tasks re-enter the eligible pool ahead of fresh `To Do` work
- [ ] Sequence override can still force a specific `Review Failed` task even when auto-retry is off
- [ ] Relevant automated tests pass

### US-007: Update docs and migration guidance from old PRD flow
**Description:** As a maintainer, I want docs and prompts updated so that future users understand Ralph now runs from backlog state instead of `prd.json`.

**Acceptance Criteria:**
- [ ] README and prompt-facing docs describe backlog-driven loop behavior
- [ ] Docs explain that backlog already must contain the tasks before Ralph starts
- [ ] Docs explain supported statuses: `To Do`, `In Progress`, `Review Failed`, `Done`
- [ ] Docs explain assignee format `<agent>@<session_id>`
- [ ] Docs explain sequence mode, verification mode, and `--retry-review-failed`
- [ ] Migration guidance states old PRD-driven runtime flow is removed
- [ ] Relevant automated tests or doc checks pass

### US-008: Add mock-based orchestration tests
**Description:** As a maintainer, I want mock-based tests around the shell boundary so that the new loop can be validated without invoking real Codex.

**Acceptance Criteria:**
- [ ] Tests use a mocked shell script in place of real Codex
- [ ] Test suite covers normal success, implementation failure, and verification failure
- [ ] Test suite covers same-session and new-session verification flows
- [ ] Test suite covers assignee/session round-trip for `codex@<session_id>`
- [ ] Test suite covers sequence override missing-task failure and `--retry-review-failed` behavior
- [ ] Test suite verifies prompt text no longer instructs agent-side task selection from `prd.json`

## Functional Requirements

- FR-1: `ralph.sh` must keep `--tool` as a public CLI option and reject any value other than `codex`
- FR-2: Ralph must select work from Backlog.md task state rather than `prd.json`
- FR-3: In default mode, Ralph must choose the highest-priority dependency-ready task in `To Do`
- FR-4: Ralph must support user-provided task order through direct sequence input and file input
- FR-5: Ralph must fail immediately if forced sequence references a task that does not exist
- FR-6: Ralph must pass assigned task text to Codex using `backlog task <task_id> --plain`
- FR-7: Ralph must store active Codex identity in assignee as `<agent>@<session_id>`
- FR-8: Ralph must set active tasks to `In Progress` before implementation work begins
- FR-9: Worker prompt must instruct Codex to write an implementation plan into the backlog task before coding
- FR-10: Worker prompt must allow Codex to refine AC and DoD before implementation
- FR-11: Worker prompt must require Codex to check AC and DoD only when truly complete
- FR-12: Worker prompt must require Codex to add a final summary to the task
- FR-13: Ralph must support verification modes `none`, `same-session`, and `new-session`
- FR-14: Verification failure must append review notes and move task to `Review Failed`
- FR-15: Ralph must support `--retry-review-failed` to re-queue failed-review tasks automatically
- FR-16: Runtime docs must describe the new backlog-driven flow and remove old PRD-driven runtime guidance
- FR-17: Automated tests must use a mocked Codex shell boundary and never invoke real Codex

## Non-Goals

- Creating backlog tasks during Ralph runtime
- Supporting Amp runtime execution
- Supporting Claude runtime execution
- Keeping PRD-driven task selection active in parallel with backlog-driven orchestration
- Building a new UI for Ralph task management

## Design Considerations

- Keep bash control flow readable by splitting logic into small helper functions
- Backlog remains the visible audit log for status, notes, review notes, AC, DoD, and final summary
- Assignee metadata doubles as resume state, so docs and tests must treat that format as stable behavior

## Technical Considerations

- Selection logic depends on what backlog CLI exposes for status, priority, and dependencies in `--plain` output
- Prompt changes likely split into worker and verifier variants, or one template with mode switch
- Tests should isolate shell orchestration from real Codex by injecting a mocked executable or command wrapper
- Migration should remove dead branches and stale docs so future changes do not have to reason about three runtimes

## Success Metrics

- Ralph can complete an iteration without reading `prd.json`
- Missing task in forced sequence fails immediately with clear error
- Review failure produces `Review Failed` plus review notes instead of false `Done`
- Maintainers can resume prior Codex work from assignee metadata alone
- Test suite validates main orchestration paths without requiring real Codex access

## Open Questions

- What exact helper layout is best: one `ralph.sh` with functions or small sourced shell helpers under `tools/ralph/`
- What exact success signal should worker and verifier Codex sessions emit back to `ralph.sh`
- What is the cleanest backlog CLI query shape for dependency-ready selection in plain text mode
