import { LABELS } from "@/lib/labels";

// Stands in for your API. Put each real request below the `testAnswer` lines. Those lines are the
// test hook: the browser checks pick the answer with `?scenario=`. Keep them, and read `?scenario=`
// nowhere else. The screen relies only on what every request does: it takes a while and it can
// fail. Real request functions should also accept an `AbortSignal` and pass it to `fetch`, so a
// screen can cancel a request it no longer needs.
export type Status = "active" | "overdue";
export type Item = { id: number; name: string; status: Status; date: Date; body: string };

// The fake server's store: deleting and adding change it until the page reloads.
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
      status: "active",
      date: new Date(),
      body: LABELS.sampleNewBody,
    };
    items = [...items, item];
    return item;
  });
}

// The test hook: the answer `?scenario=` asks for (src/screens.ts names one per state), or null to
// make the real request. An answer never comes, fails, or is a fixed value.
function testAnswer<T>(answers: Record<string, T | "never" | "fail">): Promise<T> | null {
  const scenario = new URLSearchParams(window.location.search).get("scenario");
  if (scenario === null || !(scenario in answers)) return null;
  const answer = answers[scenario];
  if (answer === "never") return new Promise(() => {});
  return respond(() => {
    if (answer === "fail") throw new Error(`Test scenario ${scenario}`);
    return answer as T;
  });
}

// Answers after a short wait, as a server does. Offline (DevTools, Network, Offline) every request
// fails, as a real one would: the error and delete-failed states need no scenario there.
async function respond<T>(answer: () => T): Promise<T> {
  await new Promise((resolve) => setTimeout(resolve, 200));
  if (!navigator.onLine) throw new Error("Offline");
  return answer();
}
