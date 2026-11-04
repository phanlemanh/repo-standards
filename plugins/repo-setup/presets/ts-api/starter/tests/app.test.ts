import { afterAll, describe, expect, it } from "vitest";

import { buildApp } from "../src/app.js";

const app = buildApp();

afterAll(async () => {
  await app.close();
});

describe("HTTP API", () => {
  it("reports health", async () => {
    const response = await app.inject({ method: "GET", url: "/health" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: "ok" });
  });

  it("greets by name", async () => {
    const response = await app.inject({ method: "GET", url: "/greet/Lan" });
    expect(response.json()).toEqual({ message: "Hello, Lan!" });
  });
});
