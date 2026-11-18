## AI agents through MCP

- `ontology/actions.yaml` is the single list of what can be done in the domain. The MCP server
  (`make mcp`, registered in `.mcp.json`) exposes every action with `agent: allowed|confirm`
  that role `agent` may run; nothing else is reachable by agents. <!-- kept: none -->
- Implement actions in the `actions` module (generated `ActionHandlers` type lists what is
  missing). Never bypass `can()`, input validation or PII redaction in the server. <!-- kept: word -->
- `agent: confirm` tools carry `_meta["anthropic/requiresUserInteraction"]`: Claude Code asks a
  person before each call. Other MCP clients may ignore it, and the server cannot tell whether
  anyone approved. Over HTTP, role `agent` gets 403 on these actions. <!-- kept: none -->
- A wider `agent:` setting changes what agents may do: never loosen one on your own. Where the
  repo has an autonomy gate (`tools/autonomy.py`), that change is high tier and a person decides. <!-- kept: autonomy-gate -->
