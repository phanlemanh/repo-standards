/** Tier "call": one request, one structured answer. Replace this example with your own task. */
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";

import { checked, modelName, type LLMClient } from "./llm.js";

const FeedbackSchema = z.object({ label: z.enum(["positive", "negative", "neutral"]) });
export type Feedback = z.infer<typeof FeedbackSchema>;

export async function classifyFeedback(text: string, client: LLMClient): Promise<Feedback> {
  const response = checked(
    await client.messages.parse({
      model: modelName(),
      max_tokens: 256,
      output_config: { effort: "low", format: zodOutputFormat(FeedbackSchema) },
      messages: [{ role: "user", content: `Classify this customer feedback:\n\n${text}` }],
    }),
  );
  if (!response.parsed_output) throw new Error("Claude did not return a valid Feedback");
  return response.parsed_output;
}
