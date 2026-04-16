# Ralph Agent Instructions

## Overview

Ralph is an autonomous AI agent loop that runs Codex repeatedly until all PRD items are complete. Each iteration is a fresh instance with clean context.

## Preliminary
- NEVER use `codex` CLI. Mock it for tests.
- NEVER read or touch tools/ralph/ralph.sh or tools/ralph/prompt-codex.md
- Use `caveman:full` style to talk with user, write docs and tasks.
- Use `basic-memory` as knowledge base (project: `ralph-backlog`). Search and write durable notes.
- Make no assumptions. If notes/docs do not answer, ask user and record answer.
- When user corrects you or you solve hard problem, write note.
- If doc too long or information hard to find, write note.

## Basic Memory
- Before searching or writing note, read relevant `memory-*` skill
- Information you expected to find in a note is missing -> add it once you have the answer.
- Learned something took significant effort -> save that knowledge in a note.
- Before writing note, ask: “Useful for future work, or only relevant to the current task?”
- When writing note, think about how you would search for it later. Include 2–3 likely search queries and write note so it answers them.

## Commands

```bash
# Run the flowchart dev server
cd flowchart && npm run dev

# Build the flowchart
cd flowchart && npm run build

# Run Ralph
./ralph.sh [max_iterations]
```

## Key Files

- `ralph.sh` - The bash loop that spawns fresh Codex instances (runtime accepts only `--tool codex`)
- `prompt.md` - Instructions given to each AMP instance
-  `CLAUDE.md` - Instructions given to each Claude Code instance
- `prompt-codex.md` - Instructions given to each Codex instance
- `prd.json.example` - Example PRD format
- `flowchart/` - Interactive React Flow diagram explaining how Ralph works
- `tests/ralph-runtime.sh` - Shell regression tests for `ralph.sh`; mock external CLIs through `PATH` and never invoke real `codex`

## Flowchart

The `flowchart/` directory contains an interactive visualization built with React Flow. It's designed for presentations - click through to reveal each step with animations.

To run locally:
```bash
cd flowchart
npm install
npm run dev
```

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## Done when

A task is done only if:
- Relevant tests pass
- Struggles, user corrections, and impactful decisions recorded

## Patterns
- Queue-driven review-flow work treats `backlog/config.yml` status order as runtime precedence source; keep `Review` between `In Progress` and `Review Failed`, and lock that order with a focused shell test instead of broad runtime edits.
- Root `config.yaml` is Ralph runtime policy file; load it in shell via `python3` + PyYAML before selection/review logic, and copy it into shell-test fixtures when runtime behavior depends on config.
- No-sequence runtime selection should build candidates from one ordered `backlog task list --sort priority --plain` pass, then load `backlog task <id> --plain` only for emitted task ids until it finds runnable work.
- Shell tests for no-sequence selection should provide ordered-list fixture content separately from status-specific fixtures; use ordered output for queue order assertions, and keep `-s "<status>"` fixtures only for completion or retry-review checks.
- Automatic candidate filtering should skip tasks whose assignee is not empty and not listed in `config.yaml` `selection.allowed_assignees`; keep higher-priority foreign-assignee tasks in ordered fixtures to prove the skip path.
- Runtime session resume state now comes only from `Labels: session_id:<id>`; tasks that still only carry legacy `Assignee: codex@<session_id>` metadata should be treated as unrunnable until metadata is fixed.
- Backlog plain output omits `Labels:` when no labels exist, so shell parsers and fixtures must tolerate a missing labels line.
- Fresh-task claim flow should use one `backlog task edit -s "In Progress" -a codex` call; if task already has session metadata, keep it resumable on the pre-run claim, and for fresh sessions persist `session_id:<id>` only after the first `thread.started` event.
- If a fresh worker launch fails before `thread.started` is captured, roll task back to `To Do` and clear assignee plus `session_id:` label metadata so startup failures do not strand backlog state.
- To test pre-launch revalidation in `tests/ralph-runtime.sh`, use per-read task fixtures like `mock-backlog/task-1.show-2.txt`; they let one ordered-list candidate become unrunnable between selection and launch without patching the mock script per test.
- Forced `--sequence` tasks are reloaded immediately before worker launch; if the task is already `Done`, picked up a foreign assignee, or otherwise became unrunnable, Ralph should fail before starting Codex.
- When consuming `codex exec --json` logs in shell, parse `thread.started`, `turn.completed`, and `turn.failed` with `jq`; shell regressions can wrap fixture-local `jq` to prove those filters run and that missing `jq` fails fast.
- Backlog-driven completion now checks fresh `backlog task list -s ... --plain` state after status edits, so shell fixtures must keep mocked task-list outputs synchronized when tasks move between statuses.
- Verification runs use `prompt-verifier.md`; verifier result comes from Codex `-o` last-message output with `<verification>PASS</verification>` or `<verification>FAIL</verification>`, while `--verify same-session` resumes worker session and `--verify new-session` starts fresh.
- Verification pass should move task to `Done`; verification failure should append reviewer feedback with `backlog task edit --append-notes`, move task to `Review Failed`, and keep worker label `session_id:<id>` for later resume.
- When changing `prompt-codex.md`, extend `tests/ralph-runtime.sh` to assert Codex stdin contains required worker instructions and no stale PRD-selection text.
- In `flowchart/src/App.tsx`, React compiler lint expects `useCallback` dependency arrays to include ref objects referenced inside the callback, even when only `.current` is mutated.
