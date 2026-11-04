import { afterEach, describe, expect, it, vi } from "vitest";

import { classifyFeedback } from "../src/ai/feedback.js";
import { LLMRefusedError, makeClient, modelName, usage, type LLMClient } from "../src/ai/llm.js";

/** Stands in for the SDK client: no test here calls the API. */
function fakeClient(label: string, stopReason = "end_turn") {
  const parse = vi.fn().mockResolvedValue({
    stop_reason: stopReason,
    parsed_output: { label },
    usage: { input_tokens: 3, output_tokens: 2 },
  });
  return { client: { messages: { parse } } as unknown as LLMClient, parse };
}

afterEach(() => {
  vi.unstubAllEnvs();
});

describe("classifyFeedback", () => {
  it("returns the label", async () => {
    expect((await classifyFeedback("great", fakeClient("positive").client)).label).toBe("positive");
  });

  it("raises on a refusal", async () => {
    await expect(classifyFeedback("x", fakeClient("neutral", "refusal").client)).rejects.toBeInstanceOf(
      LLMRefusedError,
    );
  });

  it("sets effort and sends no sampling parameters", async () => {
    const { client, parse } = fakeClient("neutral");
    await classifyFeedback("x", client);
    const params = parse.mock.calls[0]?.[0] as Record<string, unknown>;
    expect((params["output_config"] as Record<string, unknown>)["effort"]).toBe("low");
    expect(params).not.toHaveProperty("temperature");
    expect(params).not.toHaveProperty("tool_choice");
  });

  it("counts usage", async () => {
    const before = usage.inputTokens;
    await classifyFeedback("x", fakeClient("neutral").client);
    expect(usage.inputTokens).toBe(before + 3);
  });
});

describe("configuration", () => {
  it("reads the model from CLAUDE_MODEL", () => {
    vi.stubEnv("CLAUDE_MODEL", "");
    expect(modelName()).toBe("claude-opus-5-5");
    vi.stubEnv("CLAUDE_MODEL", "claude-sonnet-5-5");
    expect(modelName()).toBe("claude-sonnet-5-5");
  });

  it("builds a client without calling the API", () => {
    vi.stubEnv("ANTHROPIC_API_KEY", "test-key");
    expect(makeClient()).toBeDefined();
  });
});
