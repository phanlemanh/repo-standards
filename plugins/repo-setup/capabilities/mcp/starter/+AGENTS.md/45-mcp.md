## AI agents through MCP

- `ontology/actions.yaml` is the single list of what can be done in the domain. The MCP server
  (`make mcp`, registered in `.mcp.json`) exposes every action with `agent: allowed|confirm`
  that role `agent` may run; nothing else is reachable by agents.
- Implement actions in the `actions` module (generated `ActionHandlers` type lists what is
  missing). Never bypass `can()`, input validation or PII redaction in the server.
- `agent: confirm` actions must be confirmed by a human in the MCP client: do not add them to
  auto-approved tools. New actions or a wider `agent:` setting are domain changes (high tier).
