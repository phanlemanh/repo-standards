// Entry point: `make mcp` (Claude Code picks it up from .mcp.json).
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import { buildServer } from "./server.js";

await buildServer().connect(new StdioServerTransport());
