/** Run the evals against the real API. This costs money, so it is not part of `make check`. */
import { readFileSync } from "node:fs";

import { classifyFeedback } from "../src/ai/feedback.js";
import { makeClient, modelName, usage } from "../src/ai/llm.js";

interface Task {
  id: string;
  input: string;
  expect: string;
}

if (!process.env["ANTHROPIC_API_KEY"]) {
  console.error("evals call the real API: set ANTHROPIC_API_KEY first.");
  process.exit(2);
}

const tasks = JSON.parse(readFileSync(new URL("./tasks.json", import.meta.url), "utf-8")) as Task[];
console.log(`Running ${tasks.length} tasks on ${modelName()}. This uses your API credit.`);
const client = makeClient();
let passed = 0;
for (const task of tasks) {
  const { label } = await classifyFeedback(task.input, client);
  if (label === task.expect) passed += 1;
  console.log(`${label === task.expect ? "ok  " : "FAIL"} ${task.id}: got ${label}`);
}
console.log(`Passed ${passed}/${tasks.length}. Tokens: ${JSON.stringify(usage)}`);
process.exit(passed === tasks.length ? 0 : 1);
