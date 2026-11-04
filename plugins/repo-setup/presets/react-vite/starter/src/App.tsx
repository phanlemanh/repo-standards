import { useState } from "react";

import { greet } from "./greet.ts";

/** Example component — replace with your own UI. */
export function App() {
  const [name, setName] = useState("");

  return (
    <main>
      <h1>{greet(name)}</h1>
      <label>
        Your name{" "}
        <input
          value={name}
          onChange={(event) => {
            setName(event.target.value);
          }}
        />
      </label>
    </main>
  );
}
