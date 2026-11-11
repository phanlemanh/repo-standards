import { defineConfig } from "@playwright/test";
export default defineConfig({
  testDir: "tests/e2e",
  outputDir: "coverage/e2e",
  // One dot per test; a failure prints in full.
  reporter: "dot",
  use: { baseURL: "http://127.0.0.1:4173" },
  webServer: {
    // Build errors go to stderr, which Playwright shows; a clean build prints nothing.
    command:
      "npx tsc --noEmit >&2 && npx vite build --logLevel warn >&2 && npx vite preview --host 127.0.0.1 --port 4173",
    url: "http://127.0.0.1:4173",
    reuseExistingServer: false,
  },
});
