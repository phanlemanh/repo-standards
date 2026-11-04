import { buildApp } from "./app.js";

// Structured JSON logs (pino) — one line per event, ready for any log platform.
const app = buildApp({ logger: { level: process.env["LOG_LEVEL"] ?? "info" } });

const port = Number(process.env["PORT"] ?? 3000);
const host = process.env["HOST"] ?? "0.0.0.0";

try {
  await app.listen({ port, host });
} catch (error) {
  app.log.error(error);
  process.exit(1);
}

for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.on(signal, () => {
    void app.close().then(() => process.exit(0));
  });
}
