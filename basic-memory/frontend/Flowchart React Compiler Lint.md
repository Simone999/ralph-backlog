---
title: Flowchart React Compiler Lint
type: note
permalink: ralph-backlog/frontend/flowchart-react-compiler-lint
tags:
- frontend
- react
- lint
- flowchart
---

# Flowchart React Compiler Lint

This note captures the React compiler lint rule that hit the `flowchart` app while unrelated Ralph prompt work was being verified. The failure came from `eslint-plugin-react-hooks` rules `react-hooks/refs` and `react-hooks/preserve-manual-memoization` around `flowchart/src/App.tsx`.

Useful future searches this note should answer: "why does flowchart lint fail on refs", "react compiler preserve manual memoization in App.tsx", and "useCallback ref dependency flowchart".

The safe pattern in this repo is to keep render-time node/edge construction pure and move any `ref.current` reads into callbacks or effects. When a callback touches a ref object, include that ref object in the `useCallback` dependency array to satisfy the compiler lint, even though the ref identity is stable.

## Observations
- [gotcha] `react-hooks/refs` rejects render-time reads of `ref.current`, so initial render data should come from pure values instead of a ref-backed helper #react #lint
- [pattern] In `flowchart/src/App.tsx`, extract pure helpers for initial node and edge construction instead of calling a render-time function that reads `nodePositions.current` #flowchart #react
- [pattern] `react-hooks/preserve-manual-memoization` expects callbacks that reference a ref object to list that ref object in the dependency array #react #lint

## Relations
- relates_to [[Ralph Agent Instructions]]
