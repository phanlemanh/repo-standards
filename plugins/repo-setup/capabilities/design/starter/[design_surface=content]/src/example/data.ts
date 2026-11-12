import { LABELS } from "@/lib/labels";

// Stands in for your API. Put each real request below its `testAnswer` line and keep that line:
// in the checks it answers instead (`ready` or a `scenario`), so they never reach your server.
export type Status = "active" | "overdue";
export type Item = { id: number; name: string; status: Status; date: Date; body: string };

let items: Item[] = [
  {
    id: 1,
    name: LABELS.sampleFirstName,
    status: "active",
    date: new Date(2026, 0, 15),
    body: LABELS.sampleFirstBody,
  },
  {
    id: 2,
    name: LABELS.sampleSecondName,
    status: "overdue",
    date: new Date(2026, 1, 3),
    body: LABELS.sampleSecondBody,
  },
];

export function listItems(): Promise<Item[]> {
  const test = testAnswer<Item[]>({ ready: items, slow: "never", fail: "fail", empty: [] });
  if (test) return test;

  return respond(() => [...items]);
}

export function deleteItem(id: number): Promise<void> {
  const test = testAnswer<void>({
    ready: undefined,
    "slow-delete": "never",
    "fail-delete": "fail",
  });
  if (test) return test;

  return respond(() => {
    items = items.filter((item) => item.id !== id);
  });
}

export function createItem(): Promise<void> {
  const test = testAnswer<void>({ ready: undefined });
  if (test) return test;

  return respond(() => {
    const item: Item = {
      id: Math.max(0, ...items.map((i) => i.id)) + 1,
      name: LABELS.sampleNewName,
      status: "active",
      date: new Date(),
      body: LABELS.sampleNewBody,
    };
    items = [...items, item];
  });
}

// In the checks' builds, the answer `?scenario=` names, else `ready`; null for the real request.
function testAnswer<T>(answers: { ready: T } & Record<string, T | "never" | "fail">) {
  if (import.meta.env.MODE !== "test" && import.meta.env.MODE !== "floor") return null;
  const scenario = new URLSearchParams(window.location.search).get("scenario") ?? "ready";
  const answer = answers[scenario] ?? answers.ready;
  if (answer === "never") return new Promise<T>(() => {});
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
