# MCP server (repo-setup capability "mcp"): ontology actions as tools for AI agents.
.PHONY: mcp

mcp: ## Run the MCP server on stdio (used by .mcp.json)
	npx tsx src/mcp/stdio.ts
