"""The small layer around the Anthropic SDK. Everything that calls Claude goes through here."""

from __future__ import annotations

import os
from collections import Counter
from typing import Any, Protocol

import anthropic

DEFAULT_MODEL = "claude-opus-5-5"

# Tokens used by this process, for logs and evals.
USAGE: Counter[str] = Counter()


class LLMRefusedError(Exception):
    """Claude declined the request (stop_reason "refusal"). The application decides what to do."""


class LLMClient(Protocol):
    """The part of the SDK client this code uses, so tests can pass a fake."""

    @property
    def messages(self) -> Any: ...


def model_name() -> str:
    return os.environ.get("CLAUDE_MODEL") or DEFAULT_MODEL


def make_client() -> anthropic.Anthropic:
    return anthropic.Anthropic()


def checked(response: Any) -> Any:
    """Count usage and stop on a refusal. Call this before reading the response content."""
    usage = getattr(response, "usage", None)
    if usage is not None:
        USAGE["input_tokens"] += usage.input_tokens
        USAGE["output_tokens"] += usage.output_tokens
    if response.stop_reason == "refusal":
        raise LLMRefusedError("Claude declined this request")
    return response
