import { beforeEach, describe, expect, it } from "vitest";

import { handlers, notes, resetNotes } from "../src/actions/index.js";
import {
  AgentLimitError,
  MAX_ITERATIONS,
  agentTools,
  denyAll,
  runAgent,
  runTool,
  type AgentClient,
} from "../src/ai/agent.js";
import { LLMRefusedError } from "../src/ai/llm.js";
import type { ActionContext, ActionHandlers } from "../src/generated/ontology.js";
import { ACTIONS } from "../src/generated/ontology.js";

const ctx: ActionContext = { role: "agent", actor: "test" };
const spec = (name: string) => {
  const found = ACTIONS.find((a) => a.name === name);
  if (!found) throw new Error(name);
  return found;
};
const message = (stopReason = "end_turn", text = "done") => ({
  stop_reason: stopReason,
  content: [{ type: "text", text }],
});

/** Stands in for the SDK client: no test here calls the API. */
function fakeClient(...messages: unknown[]) {
  const calls: Record<string, unknown>[] = [];
  const toolRunner = (params: Record<string, unknown>) => {
    calls.push(params);
    return (async function* () {
      await Promise.resolve();
      yield* messages;
    })();
  };
  return { client: { beta: { messages: { toolRunner } } } as unknown as AgentClient, calls };
}

beforeEach(() => {
  resetNotes();
});

describe("agent tools", () => {
  it("does not offer forbidden actions", () => {
    expect(agentTools(handlers, ctx).map((t) => t.name).sort()).toEqual(["deleteNote", "searchNotes"]);
  });

  it("does not run a confirm action by default", async () => {
    expect(await runTool(spec("deleteNote"), { id: "n1" }, handlers, ctx, denyAll)).toContain("not confirmed");
    expect(notes.has("n1")).toBe(true);
  });

  it("runs a confirm action once approved", async () => {
    await runTool(spec("deleteNote"), { id: "n1" }, handlers, ctx, () => true);
    expect(notes.has("n1")).toBe(false);
  });

  it("redacts personal data in tool output", async () => {
    const found = JSON.parse(await runTool(spec("searchNotes"), { query: "delivery" }, handlers, ctx, denyAll)) as {
      author: string;
    }[];
    expect(found[0]?.author).toBe("[redacted]");
  });

  it("returns invalid input to the model", async () => {
    expect(await runTool(spec("searchNotes"), { nope: 1 }, handlers, ctx, denyAll)).toContain("invalid input");
  });

  it("returns handler errors to the model", async () => {
    const broken = { searchNotes: () => Promise.reject(new Error("boom")) } as unknown as ActionHandlers;
    expect(await runTool(spec("searchNotes"), { query: "x" }, broken, ctx, denyAll)).toContain("boom");
  });
});

describe("runAgent", () => {
  it("is bounded and returns the answer", async () => {
    const { client, calls } = fakeClient(message("tool_use"), message("end_turn", "found it"));
    expect(await runAgent("hello", client)).toBe("found it");
    expect(calls[0]?.["max_iterations"]).toBe(MAX_ITERATIONS);
    expect(calls[0]).not.toHaveProperty("tool_choice");
  });

  it("stops clearly when out of turns", async () => {
    await expect(runAgent("hello", fakeClient(message("tool_use")).client)).rejects.toBeInstanceOf(AgentLimitError);
  });

  it("raises on a refusal", async () => {
    await expect(runAgent("hello", fakeClient(message("refusal")).client)).rejects.toBeInstanceOf(LLMRefusedError);
  });
});
