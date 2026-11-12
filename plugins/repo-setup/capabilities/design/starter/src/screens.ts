import type { ComponentType } from "react";

import { LABELS } from "@/lib/labels";

// Every screen and its states. A path may name parts (`/orders/:id`): `visit` is then a real
// address for the checks (`/orders/1`), and the screen takes `{ params }: { params: Params }` and
// reads `params.id ?? ""`. Per state: `scenario` picks the data source's answer, `steps` is what
// the user then does, `shows` is text on the page once the state is there.
export type Params = Record<string, string>;
export type Step = { fill: string; text: string } | { press: string };
export type State = { name: string; scenario?: string; steps?: Step[]; shows: string };
export type Screen = {
  path: string;
  visit?: string;
  load: () => Promise<ComponentType<{ params: Params }>>;
  states: [State, ...State[]];
};

const askDelete: Step[] = [{ press: LABELS.deleteItem(LABELS.sampleFirstName) }];
const confirmDelete: Step[] = [...askDelete, { press: LABELS.deleteAction }];

export const SCREENS: Screen[] = [
  {
    path: "/example",
    load: () => import("@/example/ReferenceScreen").then((m) => m.ReferenceScreen),
    states: [
      { name: "ready", shows: LABELS.sampleFirstName },
      { name: "loading", scenario: "slow", shows: LABELS.loading },
      { name: "error", scenario: "fail", shows: LABELS.errorTitle },
      { name: "empty", scenario: "empty", shows: LABELS.emptyTitle },
      {
        name: "no-results",
        steps: [{ fill: LABELS.filter, text: "zzz" }],
        shows: LABELS.noResultsTitle,
      },
      { name: "confirm-delete", steps: askDelete, shows: LABELS.deleteDetail },
      { name: "saving", scenario: "slow-delete", steps: confirmDelete, shows: LABELS.saving },
      {
        name: "delete-failed",
        scenario: "fail-delete",
        steps: confirmDelete,
        shows: LABELS.deleteFailed(LABELS.sampleFirstName),
      },
    ],
  },
];

export function address(screen: Screen): string {
  return screen.visit ?? screen.path;
}

// The matching screen, fixed paths first (`/orders/new` before `/orders/:id`), and its parts.
export function pick(pathname: string): { screen: Screen; params: Params } | null {
  const fixed = SCREENS.filter((s) => !s.path.includes(":"));
  for (const screen of [...fixed, ...SCREENS.filter((s) => !fixed.includes(s))]) {
    const bits = screen.path.split(/:(\w+)/);
    const re = bits.map((b, i) => (i % 2 ? "([^/]+)" : b.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
    const found = new RegExp(`^${re.join("")}$`).exec(pathname);
    if (!found) continue;
    const params: Params = {};
    try {
      for (let i = 1; i < bits.length; i += 2)
        params[bits[i]!] = decodeURIComponent(found[(i + 1) / 2]!);
    } catch {
      return null; // a malformed address
    }
    return { screen, params };
  }
  return null;
}
