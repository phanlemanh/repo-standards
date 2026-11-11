import { useEffect, useState, type ComponentType } from "react";

import { pick } from "@/screens";

// Shows the screen registered for this path. The screen loads its own data.
export function App() {
  const [Screen, setScreen] = useState<ComponentType | null>(null);
  useEffect(() => {
    void pick(window.location.pathname)
      ?.load()
      .then((loaded) => setScreen(() => loaded));
  }, []);
  return Screen ? <Screen /> : null;
}
