import { useEffect, useState, type ComponentType } from "react";

import { LABELS } from "@/lib/labels";
import { address, pick, SCREENS, type Params } from "@/screens";

// Shows the screen registered for this address. The screen loads its own data.
export function App() {
  const [found] = useState(() => pick(window.location.pathname));
  const [Screen, setScreen] = useState<ComponentType<{ params: Params }> | "failed" | null>(null);
  useEffect(() => {
    void found?.screen.load().then(
      (loaded) => setScreen(() => loaded),
      () => setScreen("failed"),
    );
  }, [found]);
  if (found && Screen !== "failed") return Screen ? <Screen params={found.params} /> : null;
  // No screen for this address, or its code could not load: say so and offer every screen.
  return (
    <main className="mx-auto flex max-w-2xl flex-col gap-4 p-6">
      <h1 className="text-lg font-semibold">{found ? LABELS.errorTitle : LABELS.notFound}</h1>
      <ul className="flex flex-col gap-2">
        {SCREENS.map((s) => (
          <li key={s.path}>
            <a className="text-primary underline" href={address(s)}>
              {address(s)}
            </a>
          </li>
        ))}
      </ul>
    </main>
  );
}
