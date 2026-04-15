---
title: Implementation Notes
type: note
permalink: ralph-backlog/backlog/implementation-notes
tags:
- ralph
- backlog
- notes
- progress
- blockers
---

# Implementation Notes

Where do blockers and progress go? Put them in Implementation Notes. This field is the task progress log for work in flight, including intermediate decisions and blockers. Do not use this field as PR description.

Append notes as work evolves. Keep them concise, time-ordered, and readable so someone searching for progress log, blocker log, or work log lands here.

## Commands

```bash
backlog task edit 42 --notes "Initial implementation done; pending integration tests"
backlog task edit 42 --append-notes $'- Investigated root cause\n- Added tests for edge case'
```

## Formatting

Use short paragraphs or bullet lists. Prefer markdown bullets when you have several items. Include explicit newlines when appending multiline notes.

## Observations
- [concept] Implementation Notes are progress log, not reviewer summary
- [workflow] Append notes progressively as work happens
- [format] Keep notes concise and time-ordered
- [format] Prefer bullets or short paragraphs over one long line
- [usage] Blockers and intermediate decisions belong here

## Relations
- part_of [[Task Workflow]]
- relates_to [[Write the Implementation Plan]]
- relates_to [[Final Summary]]
- relates_to [[Multiline CLI Input]]