"""HTTP API generated from the ontology: `POST /v1/actions/{name}` for every action.

Contract: contracts/openapi.json (served at /contract/openapi.json). Order of checks:
API key -> action exists -> role may run it -> input valid -> handler. Responses to role
"agent" have personal data redacted. Logs never contain request bodies.
"""

from __future__ import annotations

import json
import logging
import os
from pathlib import Path
from typing import Annotated, Any

from fastapi import APIRouter, Body, Header, HTTPException
from fastapi.responses import JSONResponse

from .actions import HANDLERS
from .mcp_server import plain, redact_output, validate
from .ontology_types import ACTIONS, ActionContext, ActionHandlers, ActionSpec, can

logger = logging.getLogger(__name__)


def load_api_keys(raw: str | None = None) -> dict[str, str]:
    """API keys -> role, from the API_KEYS environment variable: '{"<key>": "<role>"}'."""
    data = json.loads(raw if raw is not None else os.environ.get("API_KEYS", "{}"))
    return {str(k): str(v) for k, v in data.items()}


def build_router(
    handlers: ActionHandlers = HANDLERS,
    api_keys: dict[str, str] | None = None,
    contract_path: str = "contracts/openapi.json",
    actions: tuple[ActionSpec, ...] = ACTIONS,
) -> APIRouter:
    keys = api_keys if api_keys is not None else load_api_keys()
    router = APIRouter()

    @router.get("/contract/openapi.json")
    def contract() -> JSONResponse:
        path = Path(contract_path)
        if not path.exists():
            raise HTTPException(status_code=404, detail="no contract")
        return JSONResponse(json.loads(path.read_text(encoding="utf-8")))

    @router.post("/v1/actions/{name}")
    def run_action(
        name: str,
        body: Annotated[dict[str, Any] | None, Body()] = None,
        authorization: Annotated[str | None, Header()] = None,
    ) -> Any:
        token = (authorization or "").removeprefix("Bearer ").strip()
        role = keys.get(token)
        if not token or role is None:
            raise HTTPException(status_code=401, detail="missing or unknown API key")
        spec = next((a for a in actions if a.name == name), None)
        if spec is None:
            raise HTTPException(status_code=404, detail=f"unknown action {name}")
        if not can(role, spec):
            raise HTTPException(status_code=403, detail=f"role {role} may not run {name}")
        args = body or {}
        errors = validate(spec.input_schema, args)
        if errors:
            detail = {"error": "invalid input", "details": errors}
            raise HTTPException(status_code=422, detail=detail)
        ctx = ActionContext(role=role, actor=f"api-key:{role}")
        data = spec.input_type(**{spec.fields[k]: v for k, v in args.items()})
        result = plain(getattr(handlers, spec.method)(data, ctx))
        logger.info("action completed", extra={"action": name, "role": role})
        return redact_output(spec, result) if role == "agent" else result

    return router
