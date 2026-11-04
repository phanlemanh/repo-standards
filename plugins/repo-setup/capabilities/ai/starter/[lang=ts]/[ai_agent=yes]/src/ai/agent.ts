/**
 * Tier "agent": Claude chooses the steps, using only the actions the ontology allows for agents.
 *
 * Each tool goes through the same checks as the MCP server. `confirm` decides whether an
 * `agent: confirm` action may run; the default refuses, so an unattended run never executes one.
 */
import type Anthropic from "@anthropic-ai/sdk";
import { betaTool } from "@anthropic-ai/sdk/helpers/beta/json-schema";

import { handlers as defaultHandlers } from "../actions/index.js";
import type { ActionContext, ActionHandlers, ActionSpec } from "../generated/ontology.js";
import { ACTIONS } from "../generated/ontology.js";
import { agentActions, redactOutput, validate } from "../mcp/server.js";
import { checked, modelName } from "./llm.js";

export type ConfirmFn = (action: string, data: Record<string, unknown>) => boolean;
export const MAX_ITERATIONS = 10;

/** The agent used all its turns without finishing. */
export class AgentLimitError extends Error {}

export type AgentClient = Pick<Anthropic, "beta">;

export const denyAll: ConfirmFn = () => false;

/** One tool call. Problems go back to the model as text, so the agent can react. */
export async function runTool(
  spec: ActionSpec,
  args: Record<string, unknown>,
  handlers: ActionHandlers,
  ctx: ActionContext,
  confirm: ConfirmFn,
): Promise<string> {
  const errors = validate(spec.inputSchema, args);
  if (errors.length > 0) return JSON.stringify({ error: "invalid input", details: errors });
  if (spec.agent === "confirm" && !confirm(spec.name, args)) {
    return JSON.stringify({ error: `${spec.name} not confirmed by a person` });
  }
  const handler = handlers[spec.name] as (input: unknown, c: ActionContext) => Promise<unknown>;
  try {
    return JSON.stringify(redactOutput(spec, await handler(args, ctx)) ?? null);
  } catch (error) {
    return JSON.stringify({ error: error instanceof Error ? error.message : String(error) });
  }
}

export function agentTools(
  handlers: ActionHandlers,
  ctx: ActionContext,
  confirm: ConfirmFn = denyAll,
  actions: readonly ActionSpec[] = ACTIONS,
) {
  return agentActions(ctx, actions).map((spec) =>
    betaTool({
      name: spec.name,
      description: spec.description,
      inputSchema: spec.inputSchema as { type: "object" },
      run: (input) => runTool(spec, input as Record<string, unknown>, handlers, ctx, confirm),
    }),
  );
}

export async function runAgent(
  prompt: string,
  client: AgentClient,
  confirm: ConfirmFn = denyAll,
): Promise<string> {
  const ctx: ActionContext = { role: "agent", actor: "agent-loop" };
  const runner = client.beta.messages.toolRunner({
    model: modelName(),
    max_tokens: 16000,
    max_iterations: MAX_ITERATIONS,
    output_config: { effort: "medium" },
    tools: agentTools(defaultHandlers, ctx, confirm),
    messages: [{ role: "user", content: prompt }],
  });
  let last: Awaited<ReturnType<typeof checked<Anthropic.Beta.BetaMessage>>> | undefined;
  for await (const message of runner) last = checked(message);
  if (!last || last.stop_reason === "tool_use") {
    throw new AgentLimitError(`no final answer after ${MAX_ITERATIONS} turns`);
  }
  return last.content.map((block) => (block.type === "text" ? block.text : "")).join("");
}
