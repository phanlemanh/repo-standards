---
type: decision
title: Modular monolith with enforced module boundaries
links: [ontology/page-types.yaml]
sources: []
---

# 0002 Modular monolith with enforced module boundaries

## Status

Accepted

## Context

We want one deployable application (simple to run, test and change) without letting the code
turn into a tangle where every part depends on every other part — which also makes it hard for
AI agents to change one area safely.

## Decision

Split business code into modules (bounded contexts) under `src/**/modules/`. Each module has a
public API and owns specific ontology entities. Allowed dependencies are declared in
`architecture/modules.yaml` and enforced by `tools/boundaries.py` in CI.

## Consequences

- Changes stay local; reviews can focus on one module and its public API.
- A module can later be extracted into a service along its existing boundary.
- New cross-module dependencies are explicit design decisions, reviewed by a human.
