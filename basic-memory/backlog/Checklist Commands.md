---
title: Checklist Commands
type: note
permalink: ralph-backlog/backlog/checklist-commands
tags:
- backlog
- checklist
- acceptance-criteria
- definition-of-done
- cli
---

# Checklist Commands

Use checklist commands when you need to add, check, uncheck, or remove acceptance criteria or definition-of-done items. Checkbox state is controlled by CLI indices, not by editing markdown checkboxes.

Multiple flags are supported. Comma-separated values and ranges are not.

## Commands

```bash
backlog task edit 42 --ac "New criterion" --ac "Another"
backlog task edit 42 --check-ac 1 --check-ac 2 --check-ac 3
backlog task edit 42 --uncheck-ac 2
backlog task edit 42 --remove-ac 2 --remove-ac 4
backlog task edit 42 --dod "Run tests" --dod "Update docs"
backlog task edit 42 --check-dod 1 --check-dod 2
backlog task edit 42 --uncheck-dod 1
backlog task edit 42 --remove-dod 2
```

Wrong forms:
- `--check-ac 1,2,3`
- `--check-ac 1-3`
- `--check 1`

## Observations
- [rule] Acceptance criteria and DoD items are edited through CLI indices
- [rule] Multiple flags are supported for add, check, uncheck, and remove operations
- [constraint] Comma-separated values and ranges are not valid checklist syntax
- [fact] DoD has its own command family: `--dod`, `--check-dod`, `--uncheck-dod`, `--remove-dod`
- [usage] Remove multiple AC items high-to-low to avoid index confusion

## Relations
- part_of [[Task Workflow]]
- relates_to [[Edit Tasks via CLI Only]]
- relates_to [[Good Acceptance Criteria]]
- relates_to [[Definition of Done]]
- relates_to [[Common Task Problems]]