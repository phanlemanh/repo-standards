import { useEffect, useState, type ComponentType } from "react";

import { pick } from "@/screens";

type Shown = { Screen: ComponentType<{ state: string }>; state: string };

// Shows the screen registered for this path, in the state named by `?state=` or else its first.
export function App() {
  const [shown, setShown] = useState<Shown | null>(null);
  useEffect(() => {
    const picked = pick(window.location.pathname, window.location.search);
    if (!picked) return;
    void picked.screen.load().then((Screen) => setShown({ Screen, state: picked.state }));
  }, []);
  return shown ? <shown.Screen state={shown.state} /> : null;
}
