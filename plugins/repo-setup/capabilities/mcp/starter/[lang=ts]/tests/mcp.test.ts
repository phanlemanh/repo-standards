import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { describe, expect, it } from "vitest";

import type { ActionContext, ActionHandlers, ActionSpec } from "../src/generated/ontology.js";
import { agentActions, buildServer, redactOutput, validate } from "../src/mcp/server.js";

// A stand-in action, so the server is tested independently of the real domain.
const echo = {
  name: "echo",
  description: "Echo text back.",
  entity: "Thing",
  kind: "query",
  roles: ["agent"],
  agent: "confirm",
  idempotent: true,
  output: "Thing[]",
  inputSchema: {
    type: "object",
    properties: { text: { type: "string" } },
    required: ["text"],
  },
} as unknown as ActionSpec;
const fakeHandlers = {
  echo: (input: { text: string }) => {
    if (input.text === "boom") return Promise.reject(new Error("boom"));
    return Promise.resolve([{ text: input.text }]);
  },
} as unknown as ActionHandlers;
const agent: ActionContext = { role: "agent", actor: "test" };

async function connect(actions?: readonly ActionSpec[]) {
  const [clientSide, serverSide] = InMemoryTransport.createLinkedPair();
  const client = new Client({ name: "test", version: "1.0.0" });
  const server = actions ? buildServer(fakeHandlers, agent, actions) : buildServer();
  await Promise.all([server.connect(serverSide), client.connect(clientSide)]);
  return client;
}

const text = (result: unknown) =>
  JSON.parse((result as { content: { text: string }[] }).content[0]?.text ?? "null") as unknown;

describe("MCP server", () => {
  it("lists exactly the actions agents may run", async () => {
    const { tools } = await (await connect()).listTools();
    expect(tools.map((t) => t.name).sort()).toEqual(
      agentActions(agent)
        .map((a) => a.name)
        .sort(),
    );
  });

  it("marks confirm actions and read-only queries", async () => {
    const { tools } = await (await connect([echo])).listTools();
    expect(tools[0]?.description).toContain("human confirmation");
    expect(tools[0]?.annotations?.readOnlyHint).toBe(true);
  });

  it("runs an allowed action", async () => {
    const result = await (await connect([echo])).callTool({ name: "echo", arguments: { text: "hi" } });
    expect(result.isError).toBe(false);
    expect(text(result)).toEqual([{ text: "hi" }]);
  });

  it("rejects invalid input, unknown tools and handler errors", async () => {
    const client = await connect([echo]);
    expect((await client.callTool({ name: "echo", arguments: {} })).isError).toBe(true);
    expect((await client.callTool({ name: "nope", arguments: {} })).isError).toBe(true);
    const failed = await client.callTool({ name: "echo", arguments: { text: "boom" } });
    expect(failed.isError).toBe(true);
    expect(text(failed)).toEqual({ error: "boom" });
  });

  it("hides actions the role may not run", () => {
    expect(agentActions({ role: "nobody", actor: "t" } as ActionContext, [echo])).toEqual([]);
  });

  it("redacts output only for entities with personal data", () => {
    const noOutput = { ...echo, output: null } as ActionSpec;
    expect(redactOutput(noOutput, { a: 1 })).toEqual({ a: 1 });
    expect(redactOutput(echo, [{ text: "x" }])).toEqual([{ text: "x" }]);
    expect(redactOutput(echo, "plain")).toBe("plain");
  });

  it("validates input against the action schema", () => {
    const schema = {
      type: "object",
      properties: {
        total: { type: "number" },
        count: { type: "integer" },
        ok: { type: "boolean" },
        channel: { type: "string", enum: ["app"] },
      },
      required: ["total"],
    };
    expect(validate(schema, { total: 1, count: 2, ok: true, channel: "app" })).toEqual([]);
    expect(validate(schema, { channel: "web", extra: 1, count: 1.5, ok: "y" })).toEqual([
      "missing 'total'",
      "'channel' must be one of app",
      "unknown field 'extra'",
      "'count' must be integer",
      "'ok' must be boolean",
    ]);
  });
});
