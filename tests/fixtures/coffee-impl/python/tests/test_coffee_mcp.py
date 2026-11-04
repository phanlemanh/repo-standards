import json

import pytest
from mcp import Client
from mcp.types import CallToolResult, TextContent

from PKG.mcp_server import build_server
from PKG.ontology_types import ActionContext


def _body(result: CallToolResult) -> dict[str, object]:
    content = result.content[0]
    assert isinstance(content, TextContent)
    data = json.loads(content.text)
    assert isinstance(data, dict)
    return data


@pytest.mark.anyio
async def test_exposes_agent_actions_and_marks_confirm() -> None:
    async with Client(build_server()) as client:
        tools = (await client.list_tools()).tools
    assert sorted(t.name for t in tools) == ["awardPoints", "getCustomer", "placeOrder"]
    award = next(t for t in tools if t.name == "awardPoints")
    assert "human confirmation" in (award.description or "")


@pytest.mark.anyio
async def test_redacts_personal_data() -> None:
    async with Client(build_server()) as client:
        body = _body(await client.call_tool("getCustomer", {"id": "c1"}))
    assert body["name"] == "Lan"
    assert body["phone"] == "[redacted]"


@pytest.mark.anyio
async def test_rejects_invalid_input() -> None:
    async with Client(build_server()) as client:
        result = await client.call_tool(
            "placeOrder", {"customerId": "c1", "total": "a lot", "channel": "fax"}
        )
    assert result.is_error


@pytest.mark.anyio
async def test_hides_actions_the_role_may_not_run() -> None:
    async with Client(build_server(ctx=ActionContext(role="staff", actor="t"))) as client:
        names = [t.name for t in (await client.list_tools()).tools]
    assert "awardPoints" not in names
