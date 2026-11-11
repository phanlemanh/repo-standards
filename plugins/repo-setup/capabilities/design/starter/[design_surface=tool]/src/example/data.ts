import { LABELS } from "@/lib/labels";

// Stands in for your API. Put each real request below its `testAnswer` line, and keep that line:
// it is the hook the checks use to pick an answer (`scenario` in src/screens.ts).
export type Status = "active" | "pending" | "overdue";
export type Item = { id: number; name: string; status: Status; date: Date; total: number };

let items: Item[] = [
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

export function listItems(): Promise<Item[]> {
  const test = testAnswer<Item[]>({ slow: "never", fail: "fail", empty: [] });
  if (test) return test;

  return respond(() => [...items]);
}

export function deleteItem(id: number): Promise<void> {
  const test = testAnswer<void>({ "slow-delete": "never", "fail-delete": "fail" });
  if (test) return test;

  return respond(() => {
    items = items.filter((item) => item.id !== id);
  });
}

export function createItem(): Promise<Item> {
  return respond(() => {
    const item: Item = {
      id: Math.max(0, ...items.map((i) => i.id)) + 1,
      name: LABELS.sampleNewName,
      status: "pending",
      date: new Date(),
      total: 0,
    };
    items = [...items, item];
    return item;
  });
}

// The answer `?scenario=` asks for in the checks' builds, or null for the real request.
function testAnswer<T>(answers: Record<string, T | "never" | "fail">): Promise<T> | null {
  if (import.meta.env.MODE !== "test" && import.meta.env.MODE !== "floor") return null;
  const scenario = new URLSearchParams(window.location.search).get("scenario");
  if (scenario === null || !(scenario in answers)) return null;
  const answer = answers[scenario];
  if (answer === "never") return new Promise(() => {});
  return respond(() => {
    if (answer === "fail") throw new Error(`Test scenario ${scenario}`);
    return answer as T;
  });
}

// Answers after a short wait, as a server does. Offline, every request fails.
async function respond<T>(answer: () => T): Promise<T> {
  await new Promise((resolve) => setTimeout(resolve, 200));
  if (!navigator.onLine) throw new Error("Offline");
  return answer();
}
