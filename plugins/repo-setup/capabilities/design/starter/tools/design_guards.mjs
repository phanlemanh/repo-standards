// Proves the design guards can still fail. Runs in `make check` and in doctor.
// Usage: node tools/design_guards.mjs [--only guards|gate|reference]
import { execSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const MODES = ["guards", "gate", "reference"];
const args = process.argv.slice(2);
const at = args.indexOf("--only");
const only = at === -1 ? null : args[at + 1];
if (args.length > 0 && (at === -1 || args.length !== 2 || !MODES.includes(only))) {
  console.error(`usage: node tools/design_guards.mjs [--only ${MODES.join("|")}]`);
  process.exit(1);
}
const want = (mode) => only === null || only === mode;

const CASES = [
  ['<div className="bg-[#123456]" />', "shadcn/no-arbitrary-values"],
  ['<div className="p-[13px]" />', "shadcn/no-arbitrary-values"],
  ['<div className="h-[37px]" />', "shadcn/no-arbitrary-values"],
  ['<div className="text-red-500" />', "shadcn/no-raw-colors"],
  ["<div style={{ padding: 13 }} />", "shadcn/no-inline-styles"],
  ['<Button className="rounded-none" />', "shadcn/no-restyle"],
  ['<div className="rounded-huge" />', "shadcn/no-unknown-classes"],
  ['<div className="p-3.25" />', "no-restricted-syntax"],
  ['<div className="h-37" />', "no-restricted-syntax"],
  ["<button />", "no-restricted-syntax"],
  ["<table />", "no-restricted-syntax"],
  ["<span>{(1).toLocaleString()}</span>", "no-restricted-syntax"],
];
const CLEAN = [
  '<div className="mt-4 flex gap-2 bg-primary text-sm" />',
  '<Button size="lg" className="mt-4 w-full" />',
];
const HEAD = 'import { Button } from "@/components/ui/button";\nexport const a = ';
const problems = [];

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) return p.endsWith(join("components", "ui")) ? [] : walk(p);
    return /\.tsx?$/.test(p) ? [p] : [];
  });
}

function read(file) {
  try {
    return readFileSync(file, "utf8");
  } catch {
    problems.push(`cannot read ${file}`);
    return "";
  }
}

async function guards() {
  let ESLint;
  try {
    ({ ESLint } = await import("eslint"));
  } catch {
    problems.push("eslint is not installed: run the install commands first");
    return;
  }
  const eslint = new ESLint();
  const lint = async (jsx) => {
    const [r] = await eslint.lintText(`${HEAD}${jsx};\n`, {
      filePath: "src/pages/guard-probe.tsx",
    });
    return r.messages.map((m) => ({
      rule: m.ruleId ?? `parse: ${m.message}`,
      error: m.severity === 2,
    }));
  };
  for (const [jsx, rule] of CASES)
    if (!(await lint(jsx)).some((m) => m.rule === rule && m.error))
      problems.push(`not caught by ${rule}: ${jsx}`);
  for (const jsx of CLEAN) {
    const hit = (await lint(jsx))
      .map((m) => m.rule)
      .filter((r) => r !== "@typescript-eslint/no-unused-vars");
    if (hit.length) problems.push(`wrongly blocked (${hit}): ${jsx}`);
  }
  let terms = [];
  try {
    terms = Object.keys(JSON.parse(readFileSync("design/terms.json", "utf8")).forbidden ?? {});
  } catch {
    problems.push("design/terms.json is missing or not valid JSON");
  }
  for (const f of existsSync("src") ? walk("src") : []) {
    const text = read(f);
    for (const line of text.split("\n"))
      if (/eslint-disable/.test(line) && !/ -- \w/.test(line))
        problems.push(`eslint-disable without a reason: ${f}`);
    const lower = text.toLowerCase();
    for (const t of terms)
      if (t && lower.includes(t.toLowerCase())) problems.push(`forbidden term "${t}": ${f}`);
  }
}

function gate() {
  let plan = "";
  try {
    plan = execSync("make -n check", { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
  } catch {
    problems.push("make -n check failed");
  }
  if (!/^npx playwright test$/m.test(plan)) problems.push("make check has no browser step");
  if (!/^\tnpx playwright test$/m.test(read("mk/design.mk")))
    problems.push("the browser step can no longer fail the gate");
}

function reference() {
  if (!existsSync("design/behaviors.md")) problems.push("design/behaviors.md is missing");
  if (!/["'`]\//.test(read("tests/e2e/routes.ts")))
    problems.push("tests/e2e/routes.ts lists no path starting with /");
  for (const [file, max] of [
    [".claude/rules/ui.md", 40],
    [".claude/skills/ui/SKILL.md", 60],
  ]) {
    const n = read(file).split("\n").length - 1;
    if (n > max) problems.push(`${file} has ${n} lines, the limit is ${max}`);
  }
}

if (want("guards")) await guards();
if (want("gate")) gate();
if (want("reference")) reference();

for (const p of problems) console.error(p);
console.log(
  problems.length
    ? `design guards: ${problems.length} problems`
    : `design guards: ${only ?? "all"} ok`,
);
process.exit(problems.length ? 1 : 0);
