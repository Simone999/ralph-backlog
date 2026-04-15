---
title: Task Workflow
type: note
permalink: ralph-backlog/backlog/task-workflow
tags:
- ralph
- backlog
- workflow
- index
- memory
---

# Task Workflow

This folder is source of truth for Backlog.md workflow in Ralph. If you are searching for PR description, progress log, checkbox commands, kanban board, browser UI, task not found, metadata out of sync, assign task, references, documentation, dependencies, or `--plain` output, start here.

Titles do not include `backlog`. Tag `backlog` carries that context instead. Notes are query-shaped on purpose so a dumb agent can search plain questions and hit one small note, not one giant doc.

## Find Right Note

- Want to know if you can patch task markdown directly: `[[Edit Tasks via CLI Only]]`
- Want task paths or file structure: `[[Task File Locations]]`
- Want machine-friendly output: `[[Plain Output for Agents]]`
- Want search patterns: `[[Search Tasks and Docs]]`
- Want status, assignee, labels, refs, docs, deps: `[[Task Metadata Commands]]`
- Want creation rules: `[[Create a Task]]`
- Want good ACs: `[[Good Acceptance Criteria]]`
- Want AC or DoD checkbox commands: `[[Checklist Commands]]`
- Want first step when taking work: `[[Start Working on a Task]]`
- Want refs/docs review rule: `[[Review References Before Planning]]`
- Want plan-writing rule: `[[Write the Implementation Plan]]`
- Want scope-creep rule: `[[Only Implement Accepted Scope]]`
- Want progress log guidance: `[[Implementation Notes]]`
- Want PR description guidance: `[[Final Summary]]`
- Want real done bar: `[[Definition of Done]]`
- Want multiline shell input: `[[Multiline CLI Input]]`
- Want troubleshooting: `[[Common Task Problems]]`
- Want board/browser/report features: `[[Board, Browser, and Reports]]`

## Observations
- [decision] Memory notes under `backlog/` replace `docs/backlog.md` as workflow source of truth
- [rule] When repo docs and memory disagree, memory wins
- [design] Notes are shaped around likely agent search queries, not the original document outline
- [design] Note titles omit `backlog`; tags carry that context
- [maintenance] Update memory first when backlog workflow changes

## Relations
- relates_to [[Edit Tasks via CLI Only]]
- relates_to [[Task File Locations]]
- relates_to [[Plain Output for Agents]]
- relates_to [[Search Tasks and Docs]]
- relates_to [[Task Metadata Commands]]
- relates_to [[Create a Task]]
- relates_to [[Good Acceptance Criteria]]
- relates_to [[Checklist Commands]]
- relates_to [[Start Working on a Task]]
- relates_to [[Review References Before Planning]]
- relates_to [[Write the Implementation Plan]]
- relates_to [[Only Implement Accepted Scope]]
- relates_to [[Implementation Notes]]
- relates_to [[Final Summary]]
- relates_to [[Definition of Done]]
- relates_to [[Multiline CLI Input]]
- relates_to [[Common Task Problems]]
- relates_to [[Board, Browser, and Reports]]
- relates_to [[Ralph Backlog Loop Design Spec]]
- relates_to [[Ralph Backlog Loop Design Decisions]]