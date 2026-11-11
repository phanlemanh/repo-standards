import { useEffect, useState, type ComponentType } from "react";

import { SCREENS } from "@/screens";

type Shown = { Screen: ComponentType<{ state: string }>; state: string };

// Shows the screen registered for this path, in the state named by `?state=` or else its first.
export function App() {
  const [shown, setShown] = useState<Shown | null>(null);
  useEffect(() => {
    const page = SCREENS.find((s) => s.path === window.location.pathname) ?? SCREENS[0];
    if (!page) return;
    const asked = new URLSearchParams(window.location.search).get("state");
    const state = asked !== null && page.states.includes(asked) ? asked : page.states[0];
    void page.load().then((Screen) => setShown({ Screen, state }));
  }, []);
  return shown ? <shown.Screen state={shown.state} /> : null;
}
