/** Agent evals against the real API. Grades the final state of the notes, not the steps taken. */
import { readFileSync } from "node:fs";

import { notes, resetNotes } from "../src/actions/index.js";
import { runAgent } from "../src/ai/agent.js";
import { makeClient, modelName, usage } from "../src/ai/llm.js";

interface Task {
  id: string;
  prompt: string;
  must_exist: string[];
  must_be_gone: string[];
}

if (!process.env["ANTHROPIC_API_KEY"]) {
  console.error("evals call the real API: set ANTHROPIC_API_KEY first.");
  process.exit(2);
}

const tasks = JSON.parse(readFileSync(new URL("./agent_tasks.json", import.meta.url), "utf-8")) as Task[];
console.log(`Running ${tasks.length} agent tasks on ${modelName()}. This uses your API credit.`);
const client = makeClient();
let passed = 0;
for (const task of tasks) {
  resetNotes();
  await runAgent(task.prompt, client);
  const ok = task.must_exist.every((id) => notes.has(id)) && !task.must_be_gone.some((id) => notes.has(id));
  if (ok) passed += 1;
  console.log(`${ok ? "ok  " : "FAIL"} ${task.id}: notes left ${[...notes.keys()].sort().join(",")}`);
}
console.log(`Passed ${passed}/${tasks.length}. Tokens: ${JSON.stringify(usage)}`);
process.exit(passed === tasks.length ? 0 : 1);
