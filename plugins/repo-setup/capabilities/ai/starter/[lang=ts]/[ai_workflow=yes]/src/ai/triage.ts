/** Tier "workflow": your code decides the steps, Claude does the work inside each step. */
import { classifyFeedback } from "./feedback.js";
import { checked, modelName, type LLMClient } from "./llm.js";

export interface Triage {
  label: string;
  reply: string | null;
}

export async function triage(text: string, client: LLMClient): Promise<Triage> {
  const { label } = await classifyFeedback(text, client);
  if (label !== "negative") return { label, reply: null }; // the gate between the steps is plain code
  const response = checked(
    await client.messages.create({
      model: modelName(),
      max_tokens: 1024,
      output_config: { effort: "low" },
      messages: [{ role: "user", content: `Write a short, kind reply to this complaint:\n\n${text}` }],
    }),
  );
  const reply = response.content.map((block) => (block.type === "text" ? block.text : "")).join("");
  return { label, reply };
}
