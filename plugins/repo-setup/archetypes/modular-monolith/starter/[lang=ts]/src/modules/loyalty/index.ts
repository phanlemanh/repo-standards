// Public API of the loyalty module. It depends on sales (architecture/modules.yaml).
import { orderTotal, type OrderLine } from "../sales/index.js";

/** 1 point per 10,000 of order value. */
export function pointsFor(lines: readonly OrderLine[]): number {
  return Math.floor(orderTotal(lines) / 10_000);
}
