"""Tier "agent": Claude chooses the steps, using only the actions the ontology allows for agents.

Each tool goes through the same checks as the MCP server. `confirm` decides whether an
`agent: confirm` action may run; the default refuses, so an unattended run never executes one.
"""

from __future__ import annotations

import json
import logging
from collections.abc import Callable
from typing import Any, Protocol

from anthropic import beta_tool

from .actions import HANDLERS
from .llm import USAGE, checked, model_name
from .mcp_server import agent_actions, plain, redact_output, validate
from .ontology_types import ACTIONS, ActionContext, ActionHandlers, ActionSpec

logger = logging.getLogger(__name__)

ConfirmFn = Callable[[str, dict[str, Any]], bool]
MAX_ITERATIONS = 10


class AgentLimitError(Exception):
    """The agent used all its turns without finishing."""


class AgentClient(Protocol):
    """The part of the SDK client the agent uses, so tests can pass a fake."""

    @property
    def beta(self) -> Any: ...


def deny_all(action: str, data: dict[str, Any]) -> bool:
    return False


def run_tool(
    spec: ActionSpec,
    args: dict[str, Any],
    handlers: ActionHandlers,
    ctx: ActionContext,
    confirm: ConfirmFn,
) -> str:
    """One tool call. Problems go back to the model as text, so the agent can react."""
    errors = validate(spec.input_schema, args)
    if errors:
        return json.dumps({"error": "invalid input", "details": errors})
    if spec.agent == "confirm" and not confirm(spec.name, args):
        return json.dumps({"error": f"{spec.name} not confirmed by a person"})
    data = spec.input_type(**{spec.fields[k]: v for k, v in args.items()})
    try:
        result = getattr(handlers, spec.method)(data, ctx)
    except Exception as exc:  # report to the model instead of ending the run
        return json.dumps({"error": str(exc)})
    return json.dumps(redact_output(spec, plain(result)), default=str)


def agent_tools(
    handlers: ActionHandlers,
    ctx: ActionContext,
    confirm: ConfirmFn = deny_all,
    actions: tuple[ActionSpec, ...] = ACTIONS,
) -> list[Any]:
    def tool_for(spec: ActionSpec) -> Any:
        def call(**kwargs: Any) -> str:
            return run_tool(spec, kwargs, handlers, ctx, confirm)

        return beta_tool(
            call, name=spec.name, description=spec.description, input_schema=spec.input_schema
        )

    return [tool_for(spec) for spec in agent_actions(ctx, actions)]


def run_agent(prompt: str, client: AgentClient, confirm: ConfirmFn = deny_all) -> str:
    ctx = ActionContext(role="agent", actor="agent-loop")
    runner = client.beta.messages.tool_runner(
        model=model_name(),
        max_tokens=16000,
        max_iterations=MAX_ITERATIONS,
        output_config={"effort": "medium"},
        tools=agent_tools(HANDLERS, ctx, confirm),
        messages=[{"role": "user", "content": prompt}],
    )
    last = None
    for message in runner:
        last = checked(message)
    if last is None or last.stop_reason == "tool_use":
        raise AgentLimitError(f"no final answer after {MAX_ITERATIONS} turns")
    logger.info("agent finished", extra={"usage": dict(USAGE)})
    return "".join(block.text for block in last.content if block.type == "text")
