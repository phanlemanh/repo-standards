"""Implementations of the ontology actions (ontology/actions.yaml), one method per action.

`HANDLERS` must satisfy the generated `ActionHandlers` protocol: mypy lists every action that
is still missing. Permission checks (`can`), input validation and PII redaction are done by the
MCP server and HTTP layer; put the business rules here or call into your domain modules.
"""

from __future__ import annotations

from .ontology_types import ActionHandlers


class Handlers:
    """Add one method per action, e.g. `def place_order(self, data, ctx) -> Order: ...`."""


HANDLERS: ActionHandlers = Handlers()
