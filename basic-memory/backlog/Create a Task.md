---
title: Create a Task
type: note
permalink: ralph-backlog/backlog/create-a-task
tags:
- ralph
- backlog
- task
- creation
- authoring
---

# Create a Task

When you create a task, capture the why and the what. Do not put implementation plan in the task at creation time. Creation-time content is title, description, acceptance criteria, and optional metadata like labels, priority, assignee, references, documentation, parent task, or draft state.

Good tasks are small enough for one PR, testable or verifiable, and independent enough to deliver value on their own.

## Commands

```bash
backlog task create "Task title" -d "Description" --ac "First criterion" --ac "Second criterion"
backlog task create "Draft title" --draft
backlog task create "Subtask" -p 42
backlog task create "Feature" --no-dod-defaults
```

## Observations
- [rule] Do not add implementation plan during task creation
- [fact] Creation phase includes title, description, acceptance criteria, and optional metadata
- [requirement] Tasks should be atomic and testable or verifiable
- [requirement] Each task should be one PR-sized unit of work
- [constraint] Tasks should not depend on future task IDs
- [strategy] Create tasks in dependency order when possible

## Relations
- part_of [[Task Workflow]]
- relates_to [[Good Acceptance Criteria]]
- relates_to [[Task Metadata Commands]]
- relates_to [[Write the Implementation Plan]]
- relates_to [[Only Implement Accepted Scope]]