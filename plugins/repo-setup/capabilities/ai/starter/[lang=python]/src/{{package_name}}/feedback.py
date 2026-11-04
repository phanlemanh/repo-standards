"""Tier "call": one request, one structured answer. Replace this example with your own task."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel

from .llm import LLMClient, checked, model_name


class Feedback(BaseModel):
    label: Literal["positive", "negative", "neutral"]


def classify_feedback(text: str, client: LLMClient) -> Feedback:
    response = checked(
        client.messages.parse(
            model=model_name(),
            max_tokens=256,
            output_config={"effort": "low"},
            output_format=Feedback,
            messages=[{"role": "user", "content": f"Classify this customer feedback:\n\n{text}"}],
        )
    )
    parsed = response.parsed_output
    if not isinstance(parsed, Feedback):
        raise ValueError("Claude did not return a valid Feedback")
    return parsed
