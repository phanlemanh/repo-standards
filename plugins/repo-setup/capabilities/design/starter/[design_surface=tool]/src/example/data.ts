import { LABELS } from "@/lib/labels";

// Stands in for your API: replace each function body with the real request, keep the signature.
// The screen relies only on what every request does: it takes a while, and it can fail.
export type Status = "active" | "pending" | "overdue";
export type Item = { id: number; name: string; status: Status; date: Date; total: number };

const ITEMS: Item[] = [
  {
    id: 1,
    name: LABELS.sampleFirstName,
    status: "active",
    date: new Date(2026, 0, 15),
    total: 1200,
  },
  {
    id: 2,
    name: LABELS.sampleSecondName,
    status: "pending",
    date: new Date(2026, 1, 3),
    total: 350,
  },
  { id: 3, name: LABELS.sampleThirdName, status: "overdue", date: new Date(2026, 2, 9), total: 90 },
];

// Tests pick how this source answers with `?scenario=`; src/screens.ts names one per state.
function scenario() {
  return new URLSearchParams(window.location.search).get("scenario");
}

export function listItems(): Promise<Item[]> {
  const s = scenario();
  if (s === "slow") return never();
  if (s === "fail") return fail("GET /items");
  return later(s === "empty" ? [] : ITEMS);
}

export function deleteItem(id: number): Promise<void> {
  const s = scenario();
  if (s === "slow-delete") return never();
  if (s === "fail-delete") return fail(`DELETE /items/${id}`);
  return later(undefined);
}

// A request that answers after a short wait, one that fails after it, and one that never answers.
// Unit tests skip the wait; they still see the pending state first.
const WAIT_MS = import.meta.env.MODE === "test" ? 0 : 200;
function later<T>(value: T): Promise<T> {
  return new Promise((resolve) => setTimeout(() => resolve(value), WAIT_MS));
}
function fail(request: string): Promise<never> {
  return new Promise((_, reject) =>
    setTimeout(() => reject(new Error(`${request} failed`)), WAIT_MS),
  );
}
function never(): Promise<never> {
  return new Promise(() => {});
}
