---
title: Multiline CLI Input
type: note
permalink: ralph-backlog/backlog/multiline-cli-input
tags:
- backlog
- cli
- multiline
- shell
---

# Multiline CLI Input

If `\n` stayed literal instead of becoming a newline, shell quoting is wrong. Backlog CLI preserves input literally. Normal quoted strings do not auto-convert `\n` into real newlines.

Use ANSI-C quoting in bash or zsh, `printf` for portable POSIX, or PowerShell backtick-newline syntax.

## Commands

```bash
backlog task edit 42 --plan $'1. A\n2. B'
backlog task edit 42 --notes "$(printf 'Line1\nLine2')"
backlog task edit 42 --append-notes $'- Added API\n- Updated tests'
backlog task edit 42 --final-summary $'Shipped A\n\nTests:\n- bun test'
```

## Observations
- [concept] Multiline backlog CLI input depends on shell-aware quoting
- [technique] Normal quoted strings pass backslash-plus-n literally
- [technique] ANSI-C quoting and `printf` reliably create real newlines
- [fact] PowerShell uses backtick-newline syntax
- [impact] Wrong quoting produces malformed plan, notes, or summary content

## Relations
- part_of [[Task Workflow]]
- relates_to [[Write the Implementation Plan]]
- relates_to [[Implementation Notes]]
- relates_to [[Final Summary]]