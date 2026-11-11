import type { ComponentType } from "react";

import { LABELS } from "@/lib/labels";

// Every screen and how to reach each of its states. The app, the unit tests and the browser checks
// all read this list, so a new screen or a new state is one entry here.
//
// A state is reached the way a user meets it: the data source answers a certain way (`scenario`,
// sent as `?scenario=` and read by the source, never by the screen), then the user acts (`steps`:
// type into the field with that label, or press the button with that name). `shows` is text the
// state puts on the page; the checks wait for it before they look.
export type Step = { fill: string; text: string } | { press: string };
export type State = { name: string; scenario?: string; steps?: Step[]; shows: string };
export type Screen = {
  path: string;
  load: () => Promise<ComponentType>;
  states: [State, ...State[]];
};

// What a user does to delete the first item: ask, then confirm.
const askDelete: Step[] = [{ press: LABELS.deleteItem(LABELS.sampleFirstName) }];
const confirmDelete: Step[] = [...askDelete, { press: LABELS.deleteAction }];

export const SCREENS: Screen[] = [
  {
    path: "/",
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

// The screen for a path, else the first one.
export function pick(pathname: string): Screen | undefined {
  return SCREENS.find((s) => s.path === pathname) ?? SCREENS[0];
}
