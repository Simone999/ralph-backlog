---
title: Common Task Problems
type: note
permalink: ralph-backlog/backlog/common-task-problems
tags:
- backlog
- troubleshooting
- task
- problems
---

# Common Task Problems

If task is not found, checklist command fails, changes do not save, or metadata looks out of sync, troubleshoot through CLI first. Do not patch task file to recover.

Most common failures are wrong task ID, wrong checklist index, or bypassing CLI.

## Fixes

- Task not found: run `backlog task list --plain` and confirm task ID
- AC will not check: run `backlog task <id> --plain` and confirm checkbox indices
- Changes not saving: make sure you used CLI, not manual file edit
- Metadata out of sync: re-edit through CLI, for example `backlog task edit 42 -s <current-status>`

## Observations
- [pitfall] Wrong task ID causes task-not-found errors
- [pitfall] Wrong checklist index causes AC or DoD update failures
- [pitfall] Manual file edits are common reason for save or sync confusion
- [recovery] Re-edit through CLI to repair metadata drift

## Relations
- part_of [[Task Workflow]]
- relates_to [[Edit Tasks via CLI Only]]
- relates_to [[Plain Output for Agents]]
- relates_to [[Checklist Commands]]