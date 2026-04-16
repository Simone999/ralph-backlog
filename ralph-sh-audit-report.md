# `ralph.sh` Audit Report

Date: 2026-04-16

Scope: manual audit of `ralph.sh`, with `prompt-codex.md`, `prompt-verifier.md`, `README.md`, `tests/ralph-runtime.sh`, and existing Basic Memory design notes used as context.

Checks run:
- `bash tests/ralph-runtime.sh`
- `bash -n ralph.sh`

Current tests pass, but audit found logic bugs and security risks not covered by the test suite.

## Findings

### 1. High: default `--verify none` path never marks successful tasks `Done`

Code:
- `ralph.sh:417` sets `VERIFY_MODE` default to `none`
- `ralph.sh:559-567` calls `mark_task_done` only inside verification branch

Impact:
- Ralph's default mode leaves completed tasks in `In Progress`
- completed work is not persisted as complete
- later runs skip those tasks because normal selection only pulls from `To Do`
- final task can never complete cleanly in default mode

Why this is real:
- worker success is accepted once `turn.completed` exists at `ralph.sh:553-555`
- after that, no status transition happens unless verification is enabled

Recommended fix:
- after successful worker completion, call `mark_task_done` when `VERIFY_MODE=none`
- add regression test that asserts task status becomes `Done` in `--verify none`

### 2. High: raw backlog task text is injected into fully privileged Codex sessions

Code:
- `ralph.sh:374` builds verifier prompt from raw `task_plain`
- `ralph.sh:538` builds worker prompt from raw `task_plain`
- `ralph.sh:488-491` default runtime is `danger-full-access` with approval policy `never`

Impact:
- malicious or compromised backlog content can instruct Codex to ignore later rules
- because task text is placed before worker/verifier instructions, attacker-controlled text gets prime prompt position
- with full filesystem access and no approval gate, prompt injection can become arbitrary local command execution or secret exfiltration

Example attack surface:
- task title, notes, references, or appended review notes containing hostile instructions
- backlog content synced from less-trusted collaborators or generated tooling

Recommended fix:
- treat task text as untrusted data, not instructions
- place immutable worker/verifier instructions first
- wrap task text in explicit quoted delimiters and tell Codex to treat it as data only
- change defaults to safer sandbox/approval settings, or require opt-in for full access

### 3. Medium: completion detection depends on worker emitting `<promise>COMPLETE</promise>`

Code:
- `ralph.sh:569-575` exits successfully only when worker output contains `<promise>COMPLETE</promise>`
- `ralph.sh:283-295` and `ralph.sh:582-584` otherwise rely on another iteration and fail when no task is selectable

Impact:
- Ralph can finish all work and still exit nonzero if worker forgets marker
- this is especially brittle because worker prompt also says not to inspect backlog board, so worker may not know whether all tasks are complete

Failure mode:
1. worker finishes last task successfully
2. verifier passes and task becomes `Done`
3. worker did not emit `<promise>COMPLETE</promise>`
4. next iteration finds no `To Do` task and Ralph dies with `no dependency-ready backlog task found`

Recommended fix:
- after each successful iteration, have script query backlog state directly
- if no eligible `To Do` or retryable `Review Failed` tasks remain, exit 0 without depending on worker marker
- keep `<promise>COMPLETE</promise>` as optional fast path, not sole success path

### 4. Medium: pre-run status update can orphan tasks in `In Progress`

Code:
- `ralph.sh:529` marks task `In Progress` before Codex session is confirmed
- `ralph.sh:542-545` may later fail to capture fresh session id
- `ralph.sh:354-359` can fail before usable work starts

Impact:
- transient Codex launch/logging issues can strand a task in `In Progress`
- if no `codex@<session_id>` was captured, default selection will skip task on later runs
- operator must repair backlog state manually

Recommended fix:
- move status update until after session capture, or rollback `In Progress` to `To Do` on startup failures
- preserve `In Progress` only when a resumable session id was actually captured
- add regression test for failed fresh start that asserts rollback or explicit recovery metadata

### 5. Medium: predictable `/tmp` last-message files can collide and leak data

Code:
- `ralph.sh:344` uses `/tmp/ralph-last-message-<epoch>.txt`
- file is not created with `mktemp`
- file is never removed

Impact:
- concurrent Ralph runs started in same second can overwrite or read each other's last-message file
- stale files in `/tmp` may expose task summaries, review notes, or other sensitive output to other local users depending on host umask

Recommended fix:
- use `mktemp` for unique file creation
- set restrictive permissions (`umask 077` or `chmod 600`)
- delete temp files with `trap` on exit

## Test Gaps

Current shell tests do not cover several real failure modes:

- no assertion that `--verify none` marks task `Done`
- no dynamic mock for `backlog task list`, so tests cannot catch "all tasks done but next iteration fails"
- no coverage for rollback behavior when task is marked `In Progress` before session capture fails
- no coverage for temp-file collision or cleanup behavior

## Suggested Priority Order

1. Fix finding 1 first. Default path is functionally broken.
2. Fix finding 2 next. This is real prompt-injection risk with dangerous defaults.
3. Fix finding 3 so completion comes from backlog state, not worker guesswork.
4. Fix findings 4 and 5 for operational safety and recoverability.
