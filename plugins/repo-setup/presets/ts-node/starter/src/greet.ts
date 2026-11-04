/** Example module — replace with your own domain code. */
export function greet(name: string): string {
  const trimmed = name.trim();
  return `Hello, ${trimmed === "" ? "world" : trimmed}!`;
}
