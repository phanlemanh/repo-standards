import { SCREENS } from "../../src/screens.ts";

// Every state of every screen in src/screens.ts; add screens there, not here.
export const ROUTES: string[] = SCREENS.flatMap(({ path, states }) =>
  states.map((state, i) => (i === 0 ? path : `${path}?state=${state}`)),
);
