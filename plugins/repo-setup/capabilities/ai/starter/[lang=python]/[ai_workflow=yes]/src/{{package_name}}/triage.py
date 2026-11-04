"""Tier "workflow": your code decides the steps, Claude does the work inside each step."""

from __future__ import annotations

from dataclasses import dataclass

from .feedback import classify_feedback
from .llm import LLMClient, checked, model_name


@dataclass(frozen=True)
class Triage:
    label: str
    reply: str | None


def triage(text: str, client: LLMClient) -> Triage:
    label = classify_feedback(text, client).label
    if label != "negative":  # the gate between the steps is plain code
        return Triage(label=label, reply=None)
    prompt = f"Write a short, kind reply to this complaint:\n\n{text}"
    response = checked(
        client.messages.create(
            model=model_name(),
            max_tokens=1024,
            output_config={"effort": "low"},
            messages=[{"role": "user", "content": prompt}],
        )
    )
    reply = "".join(block.text for block in response.content if block.type == "text")
    return Triage(label=label, reply=reply)
