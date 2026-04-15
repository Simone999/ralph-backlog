---
title: Start Working on a Task
type: note
permalink: ralph-backlog/backlog/start-working-on-a-task
tags:
- backlog
- workflow
- status
- assignee
---

# Start Working on a Task

First step when you take a task: set status to `In Progress` and assign it to yourself. Do this before planning or coding so backlog reflects ownership and active state.

This is not optional ceremony. It is the start of execution workflow.

## Command

```bash
backlog task edit 42 -s "In Progress" -a @myself
```

## Observations
- [workflow] First execution step is to mark task `In Progress`
- [workflow] First execution step also assigns current owner
- [rule] Ownership should be recorded before planning or coding starts

## Relations
- part_of [[Task Workflow]]
- relates_to [[Task Metadata Commands]]
- relates_to [[Review References Before Planning]]
- relates_to [[Write the Implementation Plan]]