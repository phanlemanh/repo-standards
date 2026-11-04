/** The small layer around the Anthropic SDK. Everything that calls Claude goes through here. */
import Anthropic from "@anthropic-ai/sdk";

export const DEFAULT_MODEL = "claude-opus-5-5";

/** Tokens used by this process, for logs and evals. */
export const usage = { inputTokens: 0, outputTokens: 0 };

/** Claude declined the request (stop_reason "refusal"). The application decides what to do. */
export class LLMRefusedError extends Error {}

/** The part of the SDK client this code uses, so tests can pass a fake. */
export type LLMClient = Pick<Anthropic, "messages">;

export function modelName(): string {
  return process.env["CLAUDE_MODEL"] || DEFAULT_MODEL;
}

export function makeClient(): Anthropic {
  return new Anthropic();
}

interface Checkable {
  stop_reason: string | null;
  usage?: { input_tokens: number; output_tokens: number };
}

/** Count usage and stop on a refusal. Call this before reading the response content. */
export function checked<T extends Checkable>(response: T): T {
  usage.inputTokens += response.usage?.input_tokens ?? 0;
  usage.outputTokens += response.usage?.output_tokens ?? 0;
  if (response.stop_reason === "refusal") throw new LLMRefusedError("Claude declined this request");
  return response;
}
