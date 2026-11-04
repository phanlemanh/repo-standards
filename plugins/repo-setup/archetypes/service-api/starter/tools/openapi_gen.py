#!/usr/bin/env python3
"""Generate the HTTP API contract (OpenAPI 3.1) from the ontology (vendored by repo-setup).

  python3 tools/openapi_gen.py --out contracts/openapi.json [--check] [--title "My API"]

Entities become components/schemas (personal data marked `x-pii: true`); every action in
ontology/actions.yaml becomes `POST /v1/actions/{name}` with its input as the request body
and its output entity as the response. The contract is the source of truth: the server
serves it, tests check the routes against it, and tools/api_compat.py blocks breaking changes.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ontology_actions
from repo_ontology import find_repo_root, load_entities


def entity_schema(name: str, data: dict[str, Any], entities: set[str]) -> dict[str, Any]:
    props = {k: v for k, v in (data.get("properties") or {}).items() if isinstance(v, dict)}
    schema = ontology_actions.json_schema(props)
    schema.pop("additionalProperties", None)
    required = [k for k, v in props.items() if v.get("required") or "default" in v]
    if required:
        schema["required"] = required
    else:
        schema.pop("required", None)
    for pname, spec in props.items():
        if spec.get("pii"):
            schema["properties"][pname]["x-pii"] = True
    if data.get("description"):
        schema["description"] = str(data["description"])
    return schema


def output_ref(output: str | None) -> dict[str, Any] | None:
    if not output:
        return None
    if output.endswith("[]"):
        return {"type": "array", "items": {"$ref": f"#/components/schemas/{output[:-2]}"}}
    return {"$ref": f"#/components/schemas/{output}"}


def build(root: Path, title: str) -> dict[str, Any]:
    entities = load_entities(root)
    error = {"$ref": "#/components/schemas/Error"}
    paths: dict[str, Any] = {
        "/health": {
            "get": {
                "operationId": "health",
                "summary": "Liveness probe",
                "security": [],
                "responses": {"200": {"description": "Service is up"}},
            }
        }
    }
    for a in ontology_actions.load_actions(root):
        name = str(a["name"])
        ok: dict[str, Any] = {"description": "Success"}
        ref = output_ref(a.get("output"))
        if ref:
            ok["content"] = {"application/json": {"schema": ref}}
        paths[f"/v1/actions/{name}"] = {
            "post": {
                "operationId": name,
                "summary": str(a.get("description") or name),
                "tags": [str(a.get("entity") or "actions")],
                "x-roles": list(a.get("roles") or []),
                "x-agent": a.get("agent", "forbidden"),
                "x-idempotent": bool(a.get("idempotent", False)),
                "requestBody": {
                    "required": True,
                    "content": {
                        "application/json": {
                            "schema": ontology_actions.json_schema(a.get("input") or {})
                        }
                    },
                },
                "responses": {
                    "200": ok,
                    "401": {"description": "Missing or unknown API key", "content": _json(error)},
                    "403": {"description": "Role may not run this action", "content": _json(error)},
                    "422": {"description": "Invalid input", "content": _json(error)},
                },
            }
        }
    schemas = {n: entity_schema(n, d, set(entities)) for n, d in entities.items()}
    schemas["Error"] = {
        "type": "object",
        "properties": {
            "error": {"type": "string"},
            "details": {"type": "array", "items": {"type": "string"}},
        },
        "required": ["error"],
    }
    return {
        "openapi": "3.1.0",
        "info": {
            "title": title,
            "version": "1",
            "description": "Generated from ontology/ by tools/openapi_gen.py. Do not edit.",
        },
        "paths": paths,
        "components": {
            "schemas": schemas,
            "securitySchemes": {"apiKey": {"type": "http", "scheme": "bearer"}},
        },
        "security": [{"apiKey": []}],
    }


def _json(schema: dict[str, Any]) -> dict[str, Any]:
    return {"application/json": {"schema": schema}}


def default_title(root: Path) -> str:
    try:
        setup = json.loads((root / ".repo-setup.json").read_text())
        return str(setup.get("vars", {}).get("project_name") or "API") + " API"
    except (OSError, json.JSONDecodeError):
        return "API"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--out", default="contracts/openapi.json")
    ap.add_argument("--root", default=None)
    ap.add_argument("--title", default=None)
    ap.add_argument("--check", action="store_true", help="fail if --out is out of date")
    args = ap.parse_args(argv)
    root = Path(args.root).resolve() if args.root else find_repo_root()
    text = json.dumps(build(root, args.title or default_title(root)), indent=2) + "\n"
    out = root / args.out
    if args.check:
        if not out.exists() or out.read_text(encoding="utf-8") != text:
            print(f"{args.out} is out of date with ontology/. Run: make gen", file=sys.stderr)
            return 1
        print(f"{args.out} is up to date")
        return 0
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
