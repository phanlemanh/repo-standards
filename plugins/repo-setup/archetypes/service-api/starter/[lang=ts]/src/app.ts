import Fastify, { type FastifyInstance, type FastifyServerOptions } from "fastify";

import { registerActionRoutes, type ActionRoutesOptions } from "./http/actions.js";

/** Builds the HTTP app. Kept separate from index.ts so tests can call it without a port. */
export function buildApp(
  options: FastifyServerOptions = {},
  routes: ActionRoutesOptions = {},
): FastifyInstance {
  const app = Fastify(options);

  // Liveness probe for load balancers and orchestrators.
  app.get("/health", () => ({ status: "ok" }));

  // Every ontology action as POST /v1/actions/{name} (see contracts/openapi.json).
  registerActionRoutes(app, routes);

  return app;
}
