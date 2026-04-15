---
title: Task File Locations
type: note
permalink: ralph-backlog/backlog/task-file-locations
tags:
- ralph
- backlog
- files
- paths
- structure
---

# Task File Locations

Tasks live under `backlog/tasks/`. Drafts live under `backlog/drafts/`. Project docs live under `backlog/docs/`. Decisions live under `backlog/decisions/`. Task filenames use `task-<id> - <title>.md`.

If you inspect a task file, expect frontmatter plus sections for Description, Acceptance Criteria, Definition of Done, Implementation Plan, Implementation Notes, and Final Summary. That structure is read-only reference. Mutations still go through CLI.

## Observations
- [fact] Tasks live under `backlog/tasks/`
- [fact] Drafts live under `backlog/drafts/`
- [fact] Project docs live under `backlog/docs/`
- [fact] Decisions live under `backlog/decisions/`
- [fact] Task filenames use `task-<id> - <title>.md`
- [rule] File structure is useful for reading, not for direct editing

## Relations
- part_of [[Task Workflow]]
- relates_to [[Edit Tasks via CLI Only]]
- relates_to [[Plain Output for Agents]]