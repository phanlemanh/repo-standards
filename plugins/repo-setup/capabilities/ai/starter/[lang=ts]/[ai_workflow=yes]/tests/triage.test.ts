import { describe, expect, it, vi } from "vitest";

import { LLMRefusedError, type LLMClient } from "../src/ai/llm.js";
import { triage } from "../src/ai/triage.js";

/** Stands in for the SDK client: no test here calls the API. */
function fakeClient(label: string, reply = "", stopReason = "end_turn") {
  const parse = vi.fn().mockResolvedValue({ stop_reason: "end_turn", parsed_output: { label } });
  const create = vi.fn().mockResolvedValue({
    stop_reason: stopReason,
    content: [{ type: "text", text: reply }],
  });
  return { client: { messages: { parse, create } } as unknown as LLMClient, create };
}

describe("triage", () => {
  it("replies to negative feedback", async () => {
    expect((await triage("awful", fakeClient("negative", "Sorry").client)).reply).toBe("Sorry");
  });

  it("skips the second call for positive feedback", async () => {
    const { client, create } = fakeClient("positive", "must not be used");
    expect((await triage("great", client)).reply).toBeNull();
    expect(create).not.toHaveBeenCalled();
  });

  it("raises on a refusal in the second step", async () => {
    await expect(triage("awful", fakeClient("negative", "", "refusal").client)).rejects.toBeInstanceOf(
      LLMRefusedError,
    );
  });
});
