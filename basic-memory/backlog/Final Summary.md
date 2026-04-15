---
title: Final Summary
type: note
permalink: ralph-backlog/backlog/final-summary
tags:
- ralph
- backlog
- final-summary
- pr-description
- wrap-up
---

# Final Summary

Final Summary is where PR description goes. Write it after implementation is complete. Do not use Implementation Notes as substitute.

Good final summary leads with outcome, then covers key changes, why they matter, tests run, and risks or follow-ups when relevant. One-line summary is only acceptable for truly tiny change.

## Commands

```bash
backlog task edit 42 --final-summary $'Outcome\n\nTests:\n- ...'
backlog task edit 42 --append-final-summary $'Added follow-up detail'
backlog task edit 42 --clear-final-summary
```

## Observations
- [concept] Final Summary is reviewer-facing PR description
- [workflow] Add Final Summary after implementation completes
- [quality] Good summary covers what changed, why, impact, tests, and risks when relevant
- [rule] Final Summary is separate from Implementation Notes
- [constraint] Avoid single-line summary unless change is truly tiny

## Relations
- part_of [[Task Workflow]]
- relates_to [[Implementation Notes]]
- relates_to [[Definition of Done]]
- relates_to [[Multiline CLI Input]]