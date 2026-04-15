---
title: Good Acceptance Criteria
type: note
permalink: ralph-backlog/backlog/good-acceptance-criteria
tags:
- backlog
- acceptance-criteria
- quality
- authoring
---

# Good Acceptance Criteria

Good acceptance criteria describe observable outcomes. They do not describe implementation steps. If you are asking whether a criterion is good, ask whether a reviewer could verify the result without caring how code was written.

Good ACs are outcome-oriented, testable or verifiable, clear, complete enough to cover task scope, and framed from user or system behavior perspective.

## Good and Bad Examples

Good:
- User can successfully log in with valid credentials
- System processes 1000 requests per second without errors
- CLI preserves literal newlines in description, plan, notes, and final summary

Bad:
- Add a new function `handleLogin()` in `auth.ts`
- Define expected behavior and document supported input patterns

## Observations
- [concept] Acceptance criteria define what must be true when task scope is complete
- [quality] Good ACs describe outcomes, not implementation steps
- [quality] Good ACs are clear and objectively verifiable
- [quality] Good ACs should collectively cover task scope
- [quality] Good ACs are framed from end-user or system behavior perspective

## Relations
- part_of [[Task Workflow]]
- relates_to [[Create a Task]]
- relates_to [[Checklist Commands]]
- relates_to [[Definition of Done]]
- relates_to [[Only Implement Accepted Scope]]