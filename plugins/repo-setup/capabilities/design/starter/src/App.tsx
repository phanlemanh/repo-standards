import { ReferenceScreen, type ScreenState } from "@/example/ReferenceScreen";

const STATES: ScreenState[] = [
  "ready",
  "loading",
  "empty",
  "error",
  "no-results",
  "saving",
  "confirm-delete",
];

export function App() {
  const asked = new URLSearchParams(window.location.search).get("state") as ScreenState | null;
  return <ReferenceScreen state={asked && STATES.includes(asked) ? asked : "ready"} />;
}
