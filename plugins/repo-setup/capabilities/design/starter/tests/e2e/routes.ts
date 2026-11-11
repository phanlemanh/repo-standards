import { address, SCREENS, type Step } from "../../src/screens.ts";

export type Route = { title: string; url: string; steps: Step[]; shows: string };

// Every state of every screen in src/screens.ts; add screens there, not here.
export const ROUTES: Route[] = SCREENS.flatMap((screen) =>
  screen.states.map(({ name, scenario, steps = [], shows }) => ({
    title: `${screen.path} ${name}`,
    url: scenario ? `${address(screen)}?scenario=${scenario}` : address(screen),
    steps,
    shows,
  })),
);
