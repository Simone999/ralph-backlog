---
title: Ralph Shell Audit Findings
type: note
permalink: ralph-backlog/testing/ralph-shell-audit-findings
tags:
- testing
- shell
- security
- audit
---

# Ralph Shell Audit Findings

This note captures bugs and security risks found during a manual audit of `ralph.sh` after the backlog-driven Codex migration. Useful future search queries this note should answer: "why does ralph leave tasks in progress", "is ralph.sh prompt injection safe", and "why can ralph fail after last task is done".

The biggest functional bug is that the default `--verify none` path never marks a successful task `Done`, because `mark_task_done` runs only inside the verification branch. That leaves completed tasks stranded in `In Progress` and makes the default mode operationally wrong.

The biggest security risk is prompt injection from backlog content. `ralph.sh` prepends raw task text to the worker and verifier prompts, then launches Codex with `danger-full-access` and approval policy `never`. If backlog text can be influenced by an untrusted source, task content can steer Codex into destructive commands or data exfiltration.

A second control-flow bug is that successful completion depends on the worker emitting `<promise>COMPLETE</promise>`. If the last task is done but the worker omits that marker, Ralph can fail on the next iteration even though backlog state is complete. Another recoverability issue is that Ralph marks tasks `In Progress` before session capture is confirmed, so launch or log-parsing failures can orphan tasks in that status. Finally, the `/tmp/ralph-last-message-<epoch>.txt` temp-file pattern is predictable, not cleaned up, and can collide across concurrent runs.

## Observations
- [bug] Default `--verify none` path never transitions successful tasks from `In Progress` to `Done` #verification #status
- [vulnerability] Raw backlog task text is prompt input ahead of worker instructions while Codex runs with `danger-full-access` and approval `never` #prompt-injection #security
- [bug] Ralph success path depends on worker emitting `<promise>COMPLETE</promise>` instead of script checking backlog state directly #completion #control-flow
- [risk] Marking tasks `In Progress` before session capture can strand tasks after startup failures #recovery #session
- [risk] Predictable `/tmp/ralph-last-message-<epoch>.txt` files can leak or collide across concurrent runs #temp-files #security
- [testing-gap] Existing shell tests pass but miss verify-none status transitions, backlog-empty completion, startup rollback, and temp-file hygiene #tests

## Relations
- relates_to [[Ralph Shell Runtime Tests]]
- relates_to [[Ralph Backlog Loop Design Spec]]
- relates_to [[Ralph Backlog Loop Design Decisions]]