import type { ComponentType } from "react";

// Every screen and the states it can show. The app, the unit tests and the browser checks all read
// this list, so a new screen or a new state is one entry here. The bare path shows the first state;
// `?state=<name>` shows any other.
export type Screen = {
  path: string;
  states: readonly [string, ...string[]];
  load: () => Promise<ComponentType<{ state: string }>>;
};

function screen<S extends string>(
  path: string,
  states: readonly [S, ...S[]],
  load: () => Promise<ComponentType<{ state: S }>>,
): Screen {
  // Safe: the app only ever passes a state from `states`.
  return { path, states, load: load as Screen["load"] };
}

export const SCREENS: Screen[] = [
  screen(
    "/",
    ["ready", "loading", "empty", "error", "no-results", "saving", "confirm-delete"],
    () => import("@/example/ReferenceScreen").then((m) => m.ReferenceScreen),
  ),
];

// The screen for an address: the path picks the screen (else the first), `?state=` picks the state
// (else the screen's first).
export function pick(pathname: string, search: string): { screen: Screen; state: string } | null {
  const screen = SCREENS.find((s) => s.path === pathname) ?? SCREENS[0];
  if (!screen) return null;
  const asked = new URLSearchParams(search).get("state");
  const state = asked !== null && screen.states.includes(asked) ? asked : screen.states[0];
  return { screen, state };
}
