---
title: Only Implement Accepted Scope
type: note
permalink: ralph-backlog/backlog/only-implement-accepted-scope
tags:
- backlog
- scope
- acceptance-criteria
- follow-up
---

# Only Implement Accepted Scope

Only implement what acceptance criteria actually cover. If you discover extra work that should happen, do not silently include it. Either update acceptance criteria first or create a follow-up task.

This keeps task scope honest and makes final completion claims trustworthy.

## Commands

```bash
backlog task edit 42 --ac "New requirement"
backlog task create "Additional feature"
```

## Observations
- [rule] Do not implement beyond accepted task scope without recording it
- [workflow] Extra required work should become updated acceptance criteria or a follow-up task
- [impact] Hidden scope growth makes done state untrustworthy

## Relations
- part_of [[Task Workflow]]
- relates_to [[Good Acceptance Criteria]]
- relates_to [[Write the Implementation Plan]]
- relates_to [[Definition of Done]]