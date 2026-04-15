---
title: Edit Tasks via CLI Only
type: note
permalink: ralph-backlog/backlog/edit-tasks-via-cli-only
tags:
- ralph
- backlog
- cli
- editing
- golden-rule
---

# Edit Tasks via CLI Only

Do not edit task markdown directly. If you want to change status, assignee, acceptance criteria, notes, final summary, or any other task field, use the `backlog` CLI. Direct file edits break metadata synchronization, Git tracking, and task relationships.

Read through CLI by default too. Direct file reads are exception path. Direct file writes are forbidden.

## Commands

```bash
backlog task edit 42 -s "In Progress"
backlog task edit 42 --check-ac 1
backlog task edit 42 --notes "Implementation complete"
```

## Observations
- [rule] Never write task markdown files directly
- [rule] Use `backlog task edit` for task mutations
- [rule] Use CLI checkbox commands instead of changing `- [ ]` by hand
- [impact] Direct edits break metadata sync, Git tracking, and task relationships
- [constraint] Direct file reads are exceptional; direct file writes are forbidden

## Relations
- part_of [[Task Workflow]]
- relates_to [[Plain Output for Agents]]
- relates_to [[Task Metadata Commands]]
- relates_to [[Checklist Commands]]
- relates_to [[Common Task Problems]]