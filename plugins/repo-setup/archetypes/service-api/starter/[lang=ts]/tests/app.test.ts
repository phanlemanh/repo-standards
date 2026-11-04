import { readFileSync } from "node:fs";

import { afterAll, describe, expect, it } from "vitest";

import { buildApp } from "../src/app.js";
import type { ActionHandlers, ActionSpec } from "../src/generated/ontology.js";
import { ACTIONS } from "../src/generated/ontology.js";
import { loadApiKeys } from "../src/http/actions.js";

// A stand-in action, so the HTTP layer is tested independently of the real domain.
const echo = {
  name: "echo",
  description: "Echo text back.",
  entity: "Thing",
  kind: "query",
  roles: ["agent"],
  agent: "allowed",
  idempotent: true,
  output: "Thing",
  inputSchema: { type: "object", properties: { text: { type: "string" } }, required: ["text"] },
} as unknown as ActionSpec;
const echoConfirm = {
  ...echo,
  name: "echoConfirm",
  agent: "confirm",
  roles: ["agent", "staff"],
} as unknown as ActionSpec;
const echoHandler = (input: { text: string }) => Promise.resolve({ text: input.text });
const handlers = { echo: echoHandler, echoConfirm: echoHandler } as unknown as ActionHandlers;

const app = buildApp(
  {},
  {
    handlers,
    actions: [echo, echoConfirm],
    apiKeys: new Map([
      ["agent-key", "agent"],
      ["other-key", "someone"],
      ["staff-key", "staff"],
    ]),
  },
);
afterAll(async () => {
  await app.close();
});

const post = (name: string, key: string | null, payload: object = {}) =>
  app.inject({
    method: "POST",
    url: `/v1/actions/${name}`,
    headers: key ? { authorization: `Bearer ${key}` } : {},
    payload,
  });

describe("HTTP API", () => {
  it("reports health", async () => {
    const response = await app.inject({ method: "GET", url: "/health" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: "ok" });
  });

  it("checks key, action, role and input — in that order", async () => {
    expect((await post("echo", null)).statusCode).toBe(401);
    expect((await post("echo", "wrong")).statusCode).toBe(401);
    expect((await post("nope", "agent-key")).statusCode).toBe(404);
    expect((await post("echo", "other-key", { text: "x" })).statusCode).toBe(403);
    expect((await post("echo", "agent-key", { text: 1 })).statusCode).toBe(422);
    const ok = await post("echo", "agent-key", { text: "hi" });
    expect(ok.statusCode).toBe(200);
    expect(ok.json()).toEqual({ text: "hi" });
  });

  it("refuses a confirm action for agents, not for people", async () => {
    const refused = await post("echoConfirm", "agent-key", { text: "hi" });
    expect(refused.statusCode).toBe(403);
    expect(JSON.stringify(refused.json())).toContain("confirm");
    expect((await post("echoConfirm", "staff-key", { text: "hi" })).statusCode).toBe(200);
  });

  it("serves the contract", async () => {
    const response = await app.inject({ method: "GET", url: "/contract/openapi.json" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ openapi: "3.1.0" });
  });

  it("returns 404 when there is no contract file", async () => {
    const bare = buildApp({}, { contractPath: "missing.json", apiKeys: new Map() });
    expect((await bare.inject({ method: "GET", url: "/contract/openapi.json" })).statusCode).toBe(404);
    await bare.close();
  });

  it("reads API keys from JSON", () => {
    expect(loadApiKeys('{"k": "staff"}').get("k")).toBe("staff");
  });
});

describe("contract", () => {
  it("has exactly one operation per ontology action", () => {
    const contract = JSON.parse(readFileSync("contracts/openapi.json", "utf-8")) as {
      paths: Record<string, unknown>;
    };
    const operations = Object.keys(contract.paths)
      .filter((p) => p.startsWith("/v1/actions/"))
      .map((p) => p.slice("/v1/actions/".length))
      .sort();
    expect(operations).toEqual(ACTIONS.map((a) => a.name).sort());
  });
});
