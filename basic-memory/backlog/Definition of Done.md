---
title: Definition of Done
type: note
permalink: ralph-backlog/backlog/definition-of-done
tags:
- ralph
- backlog
- done
- definition-of-done
- quality
---

# Definition of Done

When can you mark a task done? Only when CLI state and real engineering quality both say done. That means acceptance criteria checked, DoD checked, Final Summary present, status set to `Done`, tests passing, docs updated when needed, self-review done, and no obvious regressions.

Do not mark task done early just because code exists. If you are asking whether work is finished enough to set status `Done`, this note is the answer. Self-review before done is mandatory, not optional.

## Commands

```bash
backlog task edit 42 --check-ac 1 --check-ac 2
backlog task edit 42 --check-dod 1 --check-dod 2
backlog task edit 42 --final-summary $'Outcome\n\nTests:\n- ...'
backlog task edit 42 -s Done
```

## Observations
- [concept] Definition of done is broader than checkbox state alone
- [done_criteria] CLI completion requires AC checked, DoD checked, Final Summary added, and status set to `Done`
- [done_criteria] Engineering completion also requires tests, docs, self-review, and no obvious regressions
- [rule] Never mark task done without all done conditions satisfied

## Relations
- part_of [[Task Workflow]]
- relates_to [[Checklist Commands]]
- relates_to [[Final Summary]]
- relates_to [[Only Implement Accepted Scope]]