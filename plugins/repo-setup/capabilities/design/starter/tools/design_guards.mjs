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
// Every source file outside the vendor folder must get the floor rules exactly as a probe page does.
const isFloorRule = (r) => r.startsWith("shadcn/") || r === "no-restricted-syntax";
const VENDOR = join("src", "components", "ui");
// The one place allowed to format, and the generated types that `make ontology` checks.
const OUTSIDE_FLOOR = [join("src", "lib", "format.ts"), join("src", "generated", "ontology.ts")];
const problems = [];

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) return p === VENDOR ? [] : walk(p);
    return /\.[cm]?[jt]sx?$/.test(p) ? [p] : [];
  });
}

function isError(entry) {
  const level = Array.isArray(entry) ? entry[0] : entry;
  return level === 2 || level === "error";
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
  const probeRules =
    (await eslint.calculateConfigForFile("src/pages/guard-probe.tsx"))?.rules ?? {};
  const floorRules = Object.keys(probeRules).filter(isFloorRule);
  for (const rule of ["shadcn/no-restyle", "no-restricted-syntax"])
    if (!isError(probeRules[rule])) problems.push(`${rule} is not an error for the probe page`);
  for (const f of existsSync("src") ? walk("src") : []) {
    if (!OUTSIDE_FLOOR.includes(f)) {
      if (await eslint.isPathIgnored(f)) problems.push(`ignored by eslint: ${f}`);
      else {
        const rules = (await eslint.calculateConfigForFile(f))?.rules ?? {};
        for (const rule of floorRules)
          if (JSON.stringify(rules[rule]) !== JSON.stringify(probeRules[rule]))
            problems.push(`${rule} differs from the floor for ${f}`);
      }
    }
    const text = read(f);
    for (const line of text.split("\n"))
      if (/eslint-disable/.test(line) && !/ -- [^\s*]/.test(line))
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
  if (!/^node tools\/design_guards\.mjs$/m.test(plan))
    problems.push("make check does not run the design guards");
  const mk = read("mk/design.mk");
  if (!/^\t@?npx playwright test$/m.test(mk))
    problems.push("the browser step can no longer fail the gate");
  if (!/^\t@?node tools\/design_guards\.mjs$/m.test(mk))
    problems.push("the design guards can no longer fail the gate");
  // A make setting that ignores errors would turn every step above into decoration.
  if (existsSync("GNUmakefile"))
    problems.push(
      "GNUmakefile exists: make reads it before Makefile, so the floor cannot be verified",
    );
  const mkFiles = existsSync("mk") ? readdirSync("mk").filter((n) => n.endsWith(".mk")) : [];
  for (const f of ["Makefile", ...mkFiles.map((n) => join("mk", n))]) {
    const text = read(f);
    if (/^\s*\.IGNORE\s*:/m.test(text)) problems.push(`${f} ignores errors with .IGNORE`);
    const flags = text
      .split("\n")
      .filter((line) => /^\s*((export|override)\s+)*MAKEFLAGS\b/.test(line));
    if (flags.some((line) => /(^|[\s=])(-[a-zA-Z]*i[a-zA-Z]*|--ignore-errors)\b/.test(line)))
      problems.push(`${f} ignores errors through MAKEFLAGS`);
  }
}

function reference() {
  if (!existsSync("design/behaviors.md")) problems.push("design/behaviors.md is missing");
  if (!/\bpath:\s*["'`]\//.test(read("src/screens.ts")))
    problems.push("src/screens.ts lists no screen path starting with /");
  if (!/from\s+["'][./]*src\/screens(\.ts)?["']/.test(read("tests/e2e/routes.ts")))
    problems.push("tests/e2e/routes.ts does not take its routes from src/screens.ts");
  const n = read(".claude/rules/ui.md").split("\n").length - 1;
  if (n > 60) problems.push(`.claude/rules/ui.md has ${n} lines, the limit is 60`);
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
