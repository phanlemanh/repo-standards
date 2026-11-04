import Fastify, { type FastifyInstance, type FastifyServerOptions } from "fastify";

import { greet } from "./greet.js";

/** Builds the HTTP app. Kept separate from index.ts so tests can call it without a port. */
export function buildApp(options: FastifyServerOptions = {}): FastifyInstance {
  const app = Fastify(options);

  // Liveness probe for load balancers and orchestrators.
  app.get("/health", () => ({ status: "ok" }));

  app.get<{ Params: { name: string } }>("/greet/:name", (request) => {
    request.log.info("greet requested");
    return { message: greet(request.params.name) };
  });

  return app;
}
