import { LABELS } from "../../src/lib/labels.ts";
import { address, SCREENS, type Step } from "../../src/screens.ts";

export type Route = { title: string; url: string; steps: Step[]; shows: string };

// The screen's address with the state's scenario added to its query.
function url(at: string, scenario?: string): string {
  const u = new URL(at, "http://localhost");
  if (scenario) u.searchParams.set("scenario", scenario);
  return u.pathname + u.search;
}

// Every state of every screen in src/screens.ts, then the page for an address no screen claims.
export const ROUTES: Route[] = [
  ...SCREENS.flatMap((screen) =>
    screen.states.map(({ name, scenario, steps = [], shows }) => ({
      title: `${screen.path} ${name}`,
      url: url(address(screen), scenario),
      steps,
      shows,
    })),
  ),
  { title: "not-found", url: "/no/such/page", steps: [], shows: LABELS.notFound },
];
