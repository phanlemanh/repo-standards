import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { expect, it } from "vitest";

import { buildServer } from "../src/mcp/server.js";

async function connect(role: "agent" | "staff" = "agent") {
  const [c, s] = InMemoryTransport.createLinkedPair();
  const client = new Client({ name: "t", version: "1" });
  const { handlers } = await import("../src/actions/index.js");
  await Promise.all([buildServer(handlers, { role, actor: "t" }).connect(s), client.connect(c)]);
  return client;
}

it("exposes the agent actions, marks confirm actions", async () => {
  const { tools } = await (await connect()).listTools();
  expect(tools.map((t) => t.name).sort()).toEqual(["awardPoints", "getCustomer", "placeOrder"]);
  expect(tools.find((t) => t.name === "awardPoints")?.description).toContain("human confirmation");
  expect(tools.find((t) => t.name === "getCustomer")?.annotations?.readOnlyHint).toBe(true);
});

it("redacts personal data returned to agents", async () => {
  const result = await (await connect()).callTool({ name: "getCustomer", arguments: { id: "c1" } });
  const body = JSON.parse((result.content as { text: string }[])[0]!.text) as Record<string, unknown>;
  expect(body["name"]).toBe("Lan");
  expect(body["phone"]).toBe("[redacted]");
});

it("rejects invalid input before the handler runs", async () => {
  const result = await (await connect()).callTool({
    name: "placeOrder",
    arguments: { customerId: "c1", total: "a lot", channel: "fax" },
  });
  expect(result.isError).toBe(true);
});

it("hides actions the role may not run", async () => {
  // staff may not award points (manager only, plus agent by policy)
  const { tools } = await (await connect("staff")).listTools();
  expect(tools.map((t) => t.name)).not.toContain("awardPoints");
});
