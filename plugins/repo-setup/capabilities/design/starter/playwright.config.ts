import { defineConfig } from "@playwright/test";
export default defineConfig({
  testDir: "tests/e2e",
  outputDir: "coverage/e2e",
  // One dot per test; a failure prints in full.
  reporter: "dot",
  use: { baseURL: "http://127.0.0.1:4173" },
  webServer: {
    // Build errors go to stderr, which Playwright shows; a clean build prints nothing. Mode
    // `floor` turns on the data sources' test hook; dist/ never gets this build.
    command:
      "npx tsc --noEmit >&2 && npx vite build --mode floor --outDir coverage/floor --logLevel warn >&2 && npx vite preview --outDir coverage/floor --host 127.0.0.1 --port 4173",
    url: "http://127.0.0.1:4173",
    reuseExistingServer: false,
  },
});
