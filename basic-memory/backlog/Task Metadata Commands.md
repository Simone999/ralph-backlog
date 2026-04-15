---
title: Task Metadata Commands
type: note
permalink: ralph-backlog/backlog/task-metadata-commands
tags:
- ralph
- backlog
- cli
- metadata
- status
- assignee
---

# Task Metadata Commands

Use `backlog task edit` when you need to change title, status, assignee, labels, priority, references, documentation, or dependencies. These are task metadata changes, not file edits.

This is also where you attach supporting context before or during implementation.

## Commands

```bash
backlog task edit 42 -t "New Title"
backlog task edit 42 -s "In Progress"
backlog task edit 42 -a @sara
backlog task edit 42 -l backend,api
backlog task edit 42 --priority high
backlog task edit 42 --ref src/api.ts --ref https://github.com/issue/123
backlog task edit 42 --doc docs/spec.md --doc https://design-docs.example.com
backlog task edit 42 --dep task-1 --dep task-2
backlog task archive 42
backlog task demote 42
```

## Observations
- [rule] Task metadata changes go through `backlog task edit`
- [usage] Status and assignee changes are normal first-step workflow operations
- [usage] References and documentation carry implementation context inside the task
- [usage] Dependencies are attached through `--dep`
- [fact] Archive and demote are separate task operations

## Relations
- part_of [[Task Workflow]]
- relates_to [[Edit Tasks via CLI Only]]
- relates_to [[Start Working on a Task]]
- relates_to [[Review References Before Planning]]
- relates_to [[Create a Task]]