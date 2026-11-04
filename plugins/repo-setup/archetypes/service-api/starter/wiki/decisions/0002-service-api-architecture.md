---
type: decision
title: Contract-first service API generated from the ontology
links: [ontology/page-types.yaml]
sources: []
---

# 0002 Contract-first service API generated from the ontology

## Status

Accepted

## Context

The system is consumed by other teams, partners, apps and AI agents. Hand-written endpoints
drift from the domain model, break clients silently and give agents a different surface than
humans.

## Decision

Every domain operation is an action in `ontology/actions.yaml`. From it we generate the
OpenAPI contract (`contracts/openapi.json`), the typed handler interface and the MCP tools.
HTTP exposes each action as `POST /v1/actions/{name}`; API keys map to ontology roles.
CI fails when the contract is stale or changes in a breaking way.

## Consequences

- One definition serves API, types, permissions and agents; reviews focus on the ontology.
- RPC-style action endpoints instead of resource-style REST; add resource views later if a
  client needs them, generated from the same ontology.
- Breaking changes require a new version path and a human decision.
