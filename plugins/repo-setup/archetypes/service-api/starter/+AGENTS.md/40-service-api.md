## Architecture: Service API (contract-first)

- The API is generated from the ontology: each action in `ontology/actions.yaml` is
  `POST /v1/actions/{name}`; `make gen` rewrites `contracts/openapi.json`. Never edit the
  contract or add hand-written endpoints for domain operations: add or change an action.
- `make check` runs `api-contract` (contract matches the ontology) and `api-compat` (no breaking
  change against the default branch). Breaking changes need a new versioned path and human
  approval; never "fix" api-compat by editing the old contract.
- Auth: API keys map to ontology roles (`API_KEYS` env); permission = `can(role, action)`.
  Personal data (`pii: true`) is redacted for the `agent` role and never logged.
- Implement behaviour in the actions module; keep HTTP code thin.
