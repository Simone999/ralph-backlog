---
title: Ralph Backlog Loop Design Decisions
type: note
permalink: ralph-annotator/decisions/ralph-backlog-loop-design-decisions
tags:
- ralph
- backlog
- automation
- design
---

# Ralph Backlog Loop Design Decisions

This note captures design decisions and corrections for the Ralph loop migration from `prd.json` story management to Backlog.md task management.

The initial design question was whether `prd.json` should remain the source input with Backlog generated from it, or whether Backlog should fully replace `prd.json`. The user clarified that Ralph should run only from Backlog state. The user also clarified that task selection should move out of the agent prompt and into the loop script itself.

These decisions materially change the architecture: `ralph.sh` becomes responsible for selecting the next task and passing a concrete task to the coding agent, rather than asking the agent to inspect a PRD and choose work autonomously.

## Observations
- [decision] Backlog.md is the sole source of truth for task state in the new Ralph loop
- [decision] `ralph.sh` selects the next task instead of the coding agent
- [decision] The script passes the selected task to the agent as explicit assignment context
- [impact] Existing prompts that instruct the agent to read `prd.json` and choose the highest-priority incomplete story will need redesign
- [question] How Ralph should identify the next task among eligible backlog tasks is still unresolved
- [decision] Ralph supports two task-selection modes: dependency-aware default and user-provided sequence override
- [decision] User-provided sequence and file-based overrides are allowed as mixed control on top of normal dependency-aware selection
- [decision] Ralph assumes backlog tasks already exist rather than creating them during the loop
- [requirement] Ralph must fail fast if a user-provided task in the forced sequence is missing from backlog
- [decision] Loop workflow is: script selects task, script passes `backlog task <id> --plain` to Codex, Codex adds implementation plan, Codex reviews and updates AC/DoD, Codex implements, Codex checks AC/DoD as completed, Codex writes final summary, then loop may optionally run a verification pass before continuing
- [decision] Task context should be passed to Codex from script using `backlog task <task_id> --plain`
- [decision] Codex should own implementation planning inside the task before implementation starts
- [decision] Codex may review and modify acceptance criteria and definition of done before implementation
- [decision] Codex should update AC and DoD checkboxes during or after implementation as each item becomes done
- [question] Optional verification pass may reuse the same Codex session or use a fresh one; selection mechanism still unresolved
- [decision] Verification mode is configurable with a default and CLI override rather than being asked every iteration
- [decision] If verifier says task is not done, Ralph should add review notes, move task to a new follow-up status, and retain the previous Codex session identifier so a later iteration may resume the same agent context
- [question] Exact storage location for resumable Codex session identifiers is still unresolved
- [question] Exact status name for verifier-rejected tasks is still unresolved
- [decision] Codex resumable session identity should be stored in Backlog task assignee using `<agent>@<session_id>` format
- [impact] Ralph can recover resumable agent context directly from backlog task metadata without a separate local state file

## Relations
- relates_to [[Ralph Agent Instructions]]
- relates_to [[Backlog.md CLI Usage]]