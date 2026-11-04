/**
 * HTTP API generated from the ontology: `POST /v1/actions/{name}` for every action in
 * ontology/actions.yaml (contract: contracts/openapi.json, served at /contract/openapi.json).
 *
 * Order of checks: API key -> action exists -> role may run it -> not an agent on a confirm
 * action -> input valid -> handler.
 * Responses to role "agent" have personal data redacted. Logs never contain request bodies.
 */
import { existsSync, readFileSync } from "node:fs";

import type { FastifyInstance } from "fastify";

import { handlers as defaultHandlers } from "../actions/index.js";
import {
  ACTIONS,
  can,
  type ActionContext,
  type ActionHandlers,
  type ActionSpec,
  type Role,
} from "../generated/ontology.js";
import { redactOutput, validate } from "../mcp/server.js";

/** API keys -> role, from the API_KEYS environment variable: '{"<key>": "<role>", ...}'. */
export function loadApiKeys(raw = process.env["API_KEYS"] ?? "{}"): Map<string, Role> {
  const parsed = JSON.parse(raw) as Record<string, Role>;
  return new Map(Object.entries(parsed));
}

export interface ActionRoutesOptions {
  handlers?: ActionHandlers;
  apiKeys?: Map<string, Role>;
  contractPath?: string;
  /** Defaults to the generated ontology actions; tests can pass their own. */
  actions?: readonly ActionSpec[];
}

export function registerActionRoutes(app: FastifyInstance, options: ActionRoutesOptions = {}) {
  const handlers = options.handlers ?? defaultHandlers;
  const apiKeys = options.apiKeys ?? loadApiKeys();
  const contractPath = options.contractPath ?? "contracts/openapi.json";
  const actions = options.actions ?? ACTIONS;

  app.get("/contract/openapi.json", async (_request, reply) => {
    if (!existsSync(contractPath)) return reply.code(404).send({ error: "no contract" });
    return reply.type("application/json").send(readFileSync(contractPath, "utf-8"));
  });

  app.post<{ Params: { name: string }; Body: Record<string, unknown> | undefined }>(
    "/v1/actions/:name",
    async (request, reply) => {
      const token = (request.headers.authorization ?? "").replace(/^Bearer\s+/i, "");
      const role = apiKeys.get(token);
      if (!token || !role) return reply.code(401).send({ error: "missing or unknown API key" });

      const spec = actions.find((a) => a.name === request.params.name);
      if (!spec) return reply.code(404).send({ error: `unknown action ${request.params.name}` });
      if (!can(role, spec)) {
        return reply.code(403).send({ error: `role ${role} may not run ${spec.name}` });
      }
      if (role === "agent" && spec.agent === "confirm") {
        // No approval queue yet: an API call has no person to ask, so this stays closed.
        return reply.code(403).send({ error: `${spec.name} needs human confirmation` });
      }
      const body = request.body ?? {};
      const errors = validate(spec.inputSchema, body);
      if (errors.length > 0) return reply.code(422).send({ error: "invalid input", details: errors });

      const ctx: ActionContext = { role, actor: `api-key:${role}` };
      const handler = handlers[spec.name] as (input: unknown, c: ActionContext) => Promise<unknown>;
      const result = await handler(body, ctx);
      request.log.info({ action: spec.name, role }, "action completed");
      return role === "agent" ? redactOutput(spec, result) : (result ?? null);
    },
  );
}
