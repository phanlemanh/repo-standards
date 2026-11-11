import { SCREENS, type Step } from "../../src/screens.ts";

export type Route = { title: string; url: string; steps: Step[]; shows: string };

// Every state of every screen in src/screens.ts; add screens there, not here.
export const ROUTES: Route[] = SCREENS.flatMap(({ path, states }) =>
  states.map(({ name, scenario, steps = [], shows }) => ({
    title: `${path} ${name}`,
    url: scenario ? `${path}?scenario=${scenario}` : path,
    steps,
    shows,
  })),
);
