// Internal to the sales module.
export interface OrderLine {
  price: number;
  quantity: number;
}

export function orderTotal(lines: readonly OrderLine[]): number {
  return lines.reduce((sum, line) => sum + line.price * line.quantity, 0);
}
