---
title: Write the Implementation Plan
type: note
permalink: ralph-backlog/backlog/write-the-implementation-plan
tags:
- backlog
- plan
- implementation
- approval
---

# Write the Implementation Plan

Write implementation plan after task is assigned and in progress, but before coding starts. Plan belongs in the task, not in a separate scratch note. After writing it, share it with the user and wait for approval unless the user explicitly says to skip review.

Plan should describe how you will satisfy acceptance criteria. Check tool availability first if the plan depends on specific tools.

## Command

```bash
backlog task edit 42 --plan $'1. Analyze\n2. Implement\n3. Test'
```

## Observations
- [workflow] Implementation plan is created after ownership is recorded
- [workflow] Implementation plan is written before coding starts
- [workflow] Share plan with user and wait for approval before coding unless user skips review
- [rule] Plan belongs in task field, not in task creation phase
- [technique] Check tool availability before finalizing plan

## Relations
- part_of [[Task Workflow]]
- relates_to [[Start Working on a Task]]
- relates_to [[Review References Before Planning]]
- relates_to [[Only Implement Accepted Scope]]
- relates_to [[Multiline CLI Input]]