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
