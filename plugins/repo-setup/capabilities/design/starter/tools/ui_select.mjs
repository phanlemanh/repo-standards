// Which browser checks a change needs. On a pull request in CI, design-assembly's `affected`
// command (tools/design-assembly/affected.mjs, when the repository has it) names the screens the
// change reaches; everywhere else, and whenever that command cannot answer, every check runs.
// Usage: node tools/ui_select.mjs [--full] [--run]
//   prints {"mode": "all" | "screens", "reason": "...", "grep": "<pattern>" | null}
//   --full  every check, whatever the change (make ui-floor UI_FULL=1)
//   --run   prints the reason and runs Playwright instead: one plain run for "all"; for "screens",
//           the tests whose name holds a reached screen's route, then every test naming no screen
// Reads GITHUB_EVENT_NAME (only "pull_request" narrows) and UI_BASE, the commit the change is
// measured from (the pull request's base; without it, affected.mjs picks its own).
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import process from "node:process";

const AFFECTED = "tools/design-assembly/affected.mjs";
// A test whose name holds a word starting with "/" names a screen; the second lane runs the rest.
const NAMES_A_SCREEN = "(?:^|\\s)/";
const USAGE = "usage: node tools/ui_select.mjs [--full] [--run]";

const all = (reason) => ({ mode: "all", reason, grep: null });

const firstLine = (text) =>
  String(text ?? "")
    .trim()
    .split("\n")[0];

// affected.mjs's answer, or why it cannot be read: a narrowing read from a doubtful answer would
// skip checks nobody chose to skip.
function readAnswer(stdout) {
  let data;
  try {
    data = JSON.parse(stdout);
  } catch {
    return { problem: "it printed no JSON" };
  }
  if (data === null || typeof data !== "object" || Array.isArray(data))
    return { problem: "it printed no JSON object" };
  if (typeof data.all !== "boolean") return { problem: 'its JSON has no true or false "all"' };
  if (data.all) return { data };
  if (!Array.isArray(data.screens)) return { problem: 'its JSON has no "screens" list' };
  const routes = data.screens.map((screen) => screen?.route);
  if (routes.some((route) => typeof route !== "string"))
    return { problem: "a screen in its JSON has no route" };
  if (data.grep === null && routes.length === 0) return { data, routes };
  if (typeof data.grep !== "string" || routes.length === 0)
    return { problem: 'its "grep" does not agree with its screens' };
  try {
    new RegExp(data.grep);
  } catch {
    return { problem: 'its "grep" is no pattern' };
  }
  return { data, routes };
}

// Why affected.mjs asked for everything, from the first of its reasons.
function whyAll(data) {
  const [first] = Array.isArray(data.why) ? data.why : [];
  if (!first || typeof first.reason !== "string") return "the change reaches every screen";
  return first.file ? `${first.file} is ${first.reason}` : first.reason;
}

function select(full, env) {
  if (full) return all("every screen: a full run was asked for");
  if (env.GITHUB_EVENT_NAME !== "pull_request")
    return all("every screen: not a pull request (the main branch and a local run check all)");
  if (!existsSync(AFFECTED)) return all(`every screen: ${AFFECTED} is missing`);
  const base = env.UI_BASE ? ["--base", env.UI_BASE] : [];
  const run = spawnSync(process.execPath, [AFFECTED, "--json", ...base], {
    encoding: "utf8",
    maxBuffer: 1 << 30,
  });
  if (run.error || run.status !== 0) {
    const said = firstLine(run.error?.message ?? run.stderr) || "no reason given";
    return all(`every screen: ${AFFECTED} could not answer (exit ${run.status}: ${said})`);
  }
  const { data, routes, problem } = readAnswer(run.stdout);
  if (problem) return all(`every screen: ${AFFECTED} cannot be read: ${problem}`);
  if (data.all) return all(`every screen: ${whyAll(data)}`);
  if (data.grep === null)
    return {
      mode: "screens",
      reason: "the change reaches no screen: only the tests that name no screen run",
      grep: null,
    };
  return {
    mode: "screens",
    reason: `the change reaches ${routes.join(", ")}: their tests and the tests that name no screen run`,
    grep: data.grep,
  };
}

// One Playwright run; true when it is green.
function playwright(args) {
  const run = spawnSync("npx", ["playwright", "test", ...args], { stdio: "inherit" });
  if (run.error) console.error(`ui-floor: npx could not start: ${run.error.message}`);
  return run.status === 0;
}

// Both lanes run even when the first is red, so one run shows every failure. A lane that picks no
// test is green: the change reached nothing it would check.
function runChecks(choice) {
  console.log(`ui-floor: ${choice.reason}`);
  if (choice.mode === "all") return playwright([]);
  const byScreen =
    choice.grep === null || playwright(["--pass-with-no-tests", "--grep", choice.grep]);
  const noScreen = playwright(["--pass-with-no-tests", "--grep-invert", NAMES_A_SCREEN]);
  return byScreen && noScreen;
}

const args = process.argv.slice(2);
if (args.some((arg) => arg !== "--full" && arg !== "--run")) {
  console.error(USAGE);
  process.exit(2);
}
const choice = select(args.includes("--full"), process.env);
if (args.includes("--run")) process.exit(runChecks(choice) ? 0 : 1);
console.log(JSON.stringify(choice));
