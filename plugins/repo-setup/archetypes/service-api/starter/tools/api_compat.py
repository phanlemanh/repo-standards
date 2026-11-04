#!/usr/bin/env python3
"""Detect breaking changes in the HTTP API contract (vendored by repo-setup).

  python3 tools/api_compat.py                       # compare with origin/<default> (git)
  python3 tools/api_compat.py --base old.json --head contracts/openapi.json

Breaking (exit 1): an operation removed; a response property removed or its type changed;
a request property added as required, removed, or its type changed; enum values removed
from a request field. Additive changes (new operations, new optional inputs, new response
fields) are fine. To ship a breaking change on purpose, add a new versioned path (/v2/...)
and keep the old one until clients have moved; a human must approve it (high tier).
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

CONTRACT = "contracts/openapi.json"


def resolve(spec: dict[str, Any], schema: dict[str, Any] | None) -> dict[str, Any]:
    schema = schema or {}
    ref = schema.get("$ref")
    if isinstance(ref, str) and ref.startswith("#/components/schemas/"):
        name = ref.rsplit("/", 1)[1]
        return dict(spec.get("components", {}).get("schemas", {}).get(name, {}))
    if schema.get("type") == "array":
        return {"type": "array", "items": resolve(spec, schema.get("items"))}
    return schema


def body_schema(spec: dict[str, Any], op: dict[str, Any]) -> dict[str, Any]:
    content = (op.get("requestBody") or {}).get("content", {}).get("application/json", {})
    return resolve(spec, content.get("schema"))


def ok_schema(spec: dict[str, Any], op: dict[str, Any]) -> dict[str, Any]:
    resp = (op.get("responses") or {}).get("200") or {}
    content = resp.get("content", {}).get("application/json", {})
    return resolve(spec, content.get("schema"))


def props(schema: dict[str, Any]) -> dict[str, Any]:
    if schema.get("type") == "array":
        schema = schema.get("items") or {}
    return dict(schema.get("properties") or {})


def compare(old: dict[str, Any], new: dict[str, Any]) -> list[str]:
    problems: list[str] = []
    for path, methods in (old.get("paths") or {}).items():
        for method, op in methods.items():
            label = f"{method.upper()} {path}"
            new_op = (new.get("paths") or {}).get(path, {}).get(method)
            if new_op is None:
                problems.append(f"{label}: operation removed")
                continue
            old_in, new_in = body_schema(old, op), body_schema(new, new_op)
            old_req, new_req = set(old_in.get("required") or []), set(new_in.get("required") or [])
            for field in sorted(new_req - old_req):
                problems.append(f"{label}: request field '{field}' is now required")
            for field, schema in props(old_in).items():
                new_field = props(new_in).get(field)
                if new_field is None:
                    problems.append(f"{label}: request field '{field}' removed")
                    continue
                if schema.get("type") != new_field.get("type"):
                    problems.append(f"{label}: request field '{field}' changed type")
                lost = set(schema.get("enum") or []) - set(new_field.get("enum") or [])
                if schema.get("enum") and lost:
                    problems.append(f"{label}: request '{field}' no longer accepts {sorted(lost)}")
            old_out, new_out = ok_schema(old, op), ok_schema(new, new_op)
            for field, schema in props(old_out).items():
                new_field = props(new_out).get(field)
                if new_field is None:
                    problems.append(f"{label}: response field '{field}' removed")
                elif schema.get("type") != new_field.get("type"):
                    problems.append(f"{label}: response field '{field}' changed type")
    return problems


def from_git(ref: str) -> dict[str, Any] | None:
    try:
        text = subprocess.run(  # noqa: S603
            ["git", "show", f"{ref}:{CONTRACT}"],  # noqa: S607
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    result: dict[str, Any] = json.loads(text)
    return result


def default_base() -> str | None:
    for ref in ("origin/HEAD", "origin/main", "origin/master"):
        ok = subprocess.run(  # noqa: S603
            ["git", "rev-parse", "--verify", "--quiet", ref],  # noqa: S607
            capture_output=True,
            check=False,
        )
        if ok.returncode == 0:
            return ref
    return None


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--base", help="old contract file (default: from git origin/<default>)")
    ap.add_argument("--head", default=CONTRACT, help="new contract file")
    args = ap.parse_args(argv)

    new = json.loads(Path(args.head).read_text(encoding="utf-8"))
    old: dict[str, Any] | None
    if args.base:
        old = json.loads(Path(args.base).read_text(encoding="utf-8"))
    else:
        ref = default_base()
        old = from_git(ref) if ref else None
    if old is None:
        print("api-compat: no published contract to compare with yet (ok)")
        return 0
    problems = compare(old, new)
    if problems:
        print("Breaking API changes:", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        print("Add a /v2 path instead, or get a human to approve the break.", file=sys.stderr)
        return 1
    print(f"api-compat: no breaking changes ({len(new.get('paths') or {})} paths)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
