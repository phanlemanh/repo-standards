---
type: decision
title: Record decisions in the wiki
links: [ontology/page-types.yaml]
sources: []
---

# 0001 Record decisions in the wiki

## Status

Accepted

## Context

Decisions get lost in chat threads. New team members and AI agents repeat
old debates or undo choices without knowing why they were made.

## Decision

Every significant technical or domain decision gets a short page in
`wiki/decisions/`, numbered in order, using the sections in this page.
Agents create these pages as part of the task that made the decision.

## Consequences

- The reason behind the code is searchable and lives next to it.
- Superseded decisions are not deleted: set `Status: Superseded by NNNN`.
