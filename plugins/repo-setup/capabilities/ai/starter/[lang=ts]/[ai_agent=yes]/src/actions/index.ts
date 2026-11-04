/**
 * Implementations of the ontology actions (ontology/actions.yaml), one per action.
 * This sample keeps notes in memory. Replace it with your own domain. Permission checks, input
 * validation and PII redaction are done by the agent loop, the MCP server and the HTTP layer.
 */
import type { ActionHandlers, Note } from "../generated/ontology.js";

const SAMPLE_NOTES: readonly Note[] = [
  { id: "n1", text: "The delivery comes on Monday.", author: "alice" },
  { id: "n2", text: "Order more cups.", author: "bob" },
];

export const notes = new Map<string, Note>();

export function resetNotes(): void {
  notes.clear();
  for (const note of SAMPLE_NOTES) notes.set(note.id, note);
}
resetNotes();

export const handlers: ActionHandlers = {
  searchNotes: (input) =>
    Promise.resolve(
      [...notes.values()].filter((note) => note.text.toLowerCase().includes(input.query.toLowerCase())),
    ),
  deleteNote: (input) => {
    notes.delete(input.id);
    return Promise.resolve();
  },
  purgeNotes: () => {
    notes.clear();
    return Promise.resolve();
  },
};
