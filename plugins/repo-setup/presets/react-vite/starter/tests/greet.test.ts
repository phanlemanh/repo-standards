import { describe, expect, it } from "vitest";

import { greet } from "../src/greet.ts";

describe("greet", () => {
  it("greets by name", () => {
    expect(greet("Lan")).toBe("Hello, Lan!");
  });

  it("falls back to 'world' for blank input", () => {
    expect(greet("   ")).toBe("Hello, world!");
  });
});
