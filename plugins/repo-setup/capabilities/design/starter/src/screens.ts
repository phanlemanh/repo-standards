import type { ComponentType } from "react";

import { LABELS } from "@/lib/labels";

// Every screen and its states; the app, the unit tests and the browser checks read this list. A
// path may name parts (`/orders/:id`): the screen gets them as `params`, and `visit` is a real
// address for the checks (`/orders/1`). Per state: `scenario` picks the data source's answer,
// `steps` is what the user then does, `shows` is text on the page once the state is there.
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

// The first screen whose path matches, with the named parts; null if none does.
export function pick(pathname: string): { screen: Screen; params: Params } | null {
  for (const screen of SCREENS) {
    const found = new RegExp(`^${screen.path.replace(/:(\w+)/g, "(?<$1>[^/]+)")}$`).exec(pathname);
    if (found) {
      const parts = Object.entries(found.groups ?? {});
      return {
        screen,
        params: Object.fromEntries(parts.map(([k, v]) => [k, decodeURIComponent(v)])),
      };
    }
  }
  return null;
}
