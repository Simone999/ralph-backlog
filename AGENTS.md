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
- Backlog-driven runtime selection uses `backlog task list -s "To Do" --sort priority --plain` plus `backlog task <id> --plain`; shell tests for this path should mock both commands via `PATH` and assert selected task text reaches Codex stdin.
- Selection tests that cover multiple statuses should mock separate `backlog task list -s "<status>" --sort priority --plain` outputs per status, not one shared task-list fixture.
- Runtime session metadata now uses assignee `codex` plus label `session_id:<id>`; parse `Labels:` first for resume state, and only fall back to legacy `codex@<session_id>` assignee values while migrating touched tasks.
- Backlog plain output omits `Labels:` when no labels exist, so shell parsers and fixtures must tolerate a missing labels line.
- Fresh-task claim flow should assign `codex` before setting status `In Progress`; if task already has session metadata, keep it resumable on the pre-run claim, and for fresh sessions persist `session_id:<id>` only after the first `thread.started` event.
- If a fresh worker launch fails before `thread.started` is captured, roll task back to `To Do` and clear assignee plus `session_id:` label metadata so startup failures do not strand backlog state.
- To test session round-trips in `tests/ralph-runtime.sh`, force the same task twice via `--sequence task-1,task-1`; first iteration should capture `thread.started`, second should resume with the persisted `session_id:<id>` label.
- When consuming `codex exec --json` logs in shell, treat `turn.completed` as success and `turn.failed` as failure, and parse with `while IFS= read -r line || [[ -n "$line" ]]` so a final event without trailing newline is not dropped.
- Backlog-driven completion now checks fresh `backlog task list -s ... --plain` state after status edits, so shell fixtures must keep mocked task-list outputs synchronized when tasks move between statuses.
- Verification runs use `prompt-verifier.md`; verifier result comes from Codex `-o` last-message output with `<verification>PASS</verification>` or `<verification>FAIL</verification>`, while `--verify same-session` resumes worker session and `--verify new-session` starts fresh.
- Verification pass should move task to `Done`; verification failure should append reviewer feedback with `backlog task edit --append-notes`, move task to `Review Failed`, and keep worker label `session_id:<id>` for later resume.
- When changing `prompt-codex.md`, extend `tests/ralph-runtime.sh` to assert Codex stdin contains required worker instructions and no stale PRD-selection text.
- In `flowchart/src/App.tsx`, React compiler lint expects `useCallback` dependency arrays to include ref objects referenced inside the callback, even when only `.current` is mutated.
