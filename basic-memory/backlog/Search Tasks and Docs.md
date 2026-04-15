---
title: Search Tasks and Docs
type: note
permalink: ralph-backlog/backlog/search-tasks-and-docs
tags:
- backlog
- search
- retrieval
- plain
---

# Search Tasks and Docs

Use `backlog search` when you need to find tasks by topic. Search is fuzzy, so `auth` can match `authentication`. Search spans tasks, docs, and decisions unless you narrow it with filters like `--type task`.

Use `--plain` for machine-friendly results. If you already know you want a list view, `backlog task list` also supports filters like status and assignee.

## Commands

```bash
backlog search "auth" --plain
backlog search "login" --type task --plain
backlog search "api" --status "In Progress" --plain
backlog search "bug" --priority high --plain
backlog task list -s "To Do" --plain
backlog task list -a @sara --plain
```

## Observations
- [concept] `backlog search` is primary retrieval tool for topic-based lookup
- [search] Search is fuzzy across tasks, docs, and decisions
- [rule] Use `--plain` for AI-readable search output
- [usage] Use `--type task` when you want tasks only
- [usage] Use filtered `task list` when you already know the dimension, like status or assignee

## Relations
- part_of [[Task Workflow]]
- relates_to [[Plain Output for Agents]]
- relates_to [[Common Task Problems]]
- relates_to [[Board, Browser, and Reports]]