import { useEffect, useState, type ComponentType } from "react";

import { LABELS } from "@/lib/labels";
import { pick, type Params } from "@/screens";

// Shows the screen registered for this address. The screen loads its own data.
export function App() {
  const [found] = useState(() => pick(window.location.pathname));
  const [Screen, setScreen] = useState<ComponentType<{ params: Params }> | null>(null);
  useEffect(() => {
    void found?.screen.load().then((loaded) => setScreen(() => loaded));
  }, [found]);
  if (!found)
    return (
      <main className="mx-auto flex max-w-2xl flex-col gap-4 p-6">
        <h1 className="text-lg font-semibold">{LABELS.notFound}</h1>
      </main>
    );
  return Screen ? <Screen params={found.params} /> : null;
}
