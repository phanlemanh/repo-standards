import { describe, expect, it } from "vitest";

import { pointsFor } from "../src/modules/loyalty/index.js";
import { orderTotal } from "../src/modules/sales/index.js";

describe("modules", () => {
  it("sales computes the order total", () => {
    expect(orderTotal([{ price: 25_000, quantity: 2 }])).toBe(50_000);
  });

  it("loyalty awards points through the sales public API", () => {
    expect(pointsFor([{ price: 25_000, quantity: 2 }])).toBe(5);
  });
});
