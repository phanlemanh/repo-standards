"""Implementations of the ontology actions (ontology/actions.yaml), one method per action.

This sample keeps notes in memory. Replace it with your own domain. Permission checks, input
validation and PII redaction are done by the agent loop, the MCP server and the HTTP layer.
"""

from __future__ import annotations

from .ontology_types import (
    ActionContext,
    ActionHandlers,
    DeleteNoteInput,
    Note,
    PurgeNotesInput,
    SearchNotesInput,
)

SAMPLE_NOTES = (
    Note(id="n1", text="The delivery comes on Monday.", author="alice"),
    Note(id="n2", text="Order more cups.", author="bob"),
)
NOTES: dict[str, Note] = {note.id: note for note in SAMPLE_NOTES}


def reset_notes() -> None:
    NOTES.clear()
    NOTES.update({note.id: note for note in SAMPLE_NOTES})


class Handlers:
    def search_notes(self, data: SearchNotesInput, ctx: ActionContext) -> list[Note]:
        return [note for note in NOTES.values() if data.query.lower() in note.text.lower()]

    def delete_note(self, data: DeleteNoteInput, ctx: ActionContext) -> None:
        NOTES.pop(data.id, None)

    def purge_notes(self, data: PurgeNotesInput, ctx: ActionContext) -> None:
        NOTES.clear()


HANDLERS: ActionHandlers = Handlers()
