---
title: Plain Output for Agents
type: note
permalink: ralph-backlog/backlog/plain-output-for-agents
tags:
- ralph
- backlog
- plain
- cli
- reading
---

# Plain Output for Agents

Use `--plain` when you want AI-readable task output. This is the default way to read tasks, list work, and search content without markdown noise.

Use plain output for `backlog task <id>`, `backlog task list`, and `backlog search`. Dumb agent should prefer this before looking at raw files.

## Commands

```bash
backlog task 42 --plain
backlog task list --plain
backlog search "auth" --plain
```

## Observations
- [rule] Use `--plain` for AI-readable CLI output
- [usage] Plain output is preferred for viewing, listing, and searching tasks
- [impact] Plain output reduces formatting noise for agents

## Relations
- part_of [[Task Workflow]]
- relates_to [[Edit Tasks via CLI Only]]
- relates_to [[Search Tasks and Docs]]
- relates_to [[Common Task Problems]]