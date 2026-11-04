"""Actions, roles and personal data in the ontology (vendored by repo-setup).

ontology/roles.yaml
    roles:
      - { name: staff, description: Shop employees }
      - { name: manager, inherits: [staff] }
      - { name: agent, description: AI agents acting through MCP / API }

ontology/actions.yaml — what can be DONE in the domain (one definition -> types, API, MCP tools)
    actions:
      - name: placeOrder               # camelCase verb + noun
        description: A customer places an order.
        entity: Order                  # main entity (optional)
        kind: create                   # create | update | delete | query | command
        input:
          customerId: { type: ref, target: Customer, required: true }
          total: { type: number, required: true }
        output: Order                  # entity, "Entity[]", or omit
        roles: [staff, agent]          # who may run it (inherited roles count)
        agent: allowed                 # allowed | confirm | forbidden  (exposure to AI agents)
        idempotent: false

Entity properties may carry `pii: true` (personal data): generated helpers redact them in
anything returned to agents or written to logs.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from repo_ontology import load_yaml_file

KINDS = {"create", "update", "delete", "query", "command"}
AGENT_MODES = {"allowed", "confirm", "forbidden"}
JSON_TYPES = {
    "string": {"type": "string"},
    "text": {"type": "string"},
    "uuid": {"type": "string", "format": "uuid"},
    "date": {"type": "string", "format": "date"},
    "datetime": {"type": "string", "format": "date-time"},
    "integer": {"type": "integer"},
    "number": {"type": "number"},
    "boolean": {"type": "boolean"},
}
TS_TYPES = {"integer": "number", "number": "number", "boolean": "boolean"}
PY_TYPES = {
    "integer": "int",
    "number": "float",
    "boolean": "bool",
    "date": "datetime.date",
    "datetime": "datetime.datetime",
}


def load_actions(root: Path) -> list[dict[str, Any]]:
    data = load_yaml_file(root / "ontology" / "actions.yaml") or {}
    items = data.get("actions") if isinstance(data, dict) else None
    return [a for a in (items or []) if isinstance(a, dict)]


def load_roles(root: Path) -> list[dict[str, Any]]:
    data = load_yaml_file(root / "ontology" / "roles.yaml") or {}
    items = data.get("roles") if isinstance(data, dict) else None
    return [r for r in (items or []) if isinstance(r, dict)]


def pii_fields(entities: dict[str, dict[str, Any]]) -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    for name, data in entities.items():
        props = data.get("properties") or {}
        fields = [p for p, s in props.items() if isinstance(s, dict) and s.get("pii")]
        if fields:
            out[name] = fields
    return out


def has_any(root: Path, entities: dict[str, dict[str, Any]]) -> bool:
    return bool(load_actions(root) or load_roles(root) or pii_fields(entities))


# ----------------------------------------------------------------------------- lint


def lint(root: Path, entities: dict[str, dict[str, Any]], error: Any, warn: Any) -> None:
    """Report problems through error(path, msg) / warn(path, msg)."""
    roles = load_roles(root)
    role_names = [str(r.get("name")) for r in roles]
    rpath = "ontology/roles.yaml"
    for r in roles:
        for parent in r.get("inherits") or []:
            if parent not in role_names:
                error(rpath, f"role '{r.get('name')}' inherits unknown role '{parent}'")
    if len(set(role_names)) != len(role_names):
        error(rpath, "duplicate role names")

    apath = "ontology/actions.yaml"
    seen: set[str] = set()
    for a in load_actions(root):
        name = str(a.get("name") or "")
        label = f"action '{name}'"
        if not re.fullmatch(r"[a-z][A-Za-z0-9]*", name):
            error(apath, f"{label}: name must be camelCase (e.g. placeOrder)")
        if name in seen:
            error(apath, f"{label}: duplicate name")
        seen.add(name)
        if not a.get("description"):
            warn(apath, f"{label}: missing description")
        if a.get("entity") and a["entity"] not in entities:
            error(apath, f"{label}: entity '{a['entity']}' not found")
        if a.get("kind", "command") not in KINDS:
            error(apath, f"{label}: kind must be one of {', '.join(sorted(KINDS))}")
        if a.get("agent", "forbidden") not in AGENT_MODES:
            error(apath, f"{label}: agent must be one of {', '.join(sorted(AGENT_MODES))}")
        if a.get("agent", "forbidden") == "forbidden" and "agent" in (a.get("roles") or []):
            error(apath, f"{label}: lists role 'agent' but agents are forbidden: "
                         "set agent: allowed or confirm, or remove the role")
        out = str(a.get("output") or "").removesuffix("[]")
        if out and out not in entities:
            error(apath, f"{label}: output '{a.get('output')}' is not an entity")
        for role in a.get("roles") or []:
            if role_names and role not in role_names:
                error(apath, f"{label}: role '{role}' is not in ontology/roles.yaml")
        if not a.get("roles"):
            warn(apath, f"{label}: no roles: nobody may run it")
        exposed = a.get("agent") in ("allowed", "confirm") and "agent" in role_names
        if exposed and not _role_allows("agent", a.get("roles") or [], roles):
            warn(apath, f"{label}: exposed to agents but role 'agent' may not run it")
        for field, spec in (a.get("input") or {}).items():
            if not isinstance(spec, dict) or spec.get("type") not in {*JSON_TYPES, "enum", "ref"}:
                error(apath, f"{label}: input '{field}' needs a valid type")
            elif spec["type"] == "ref" and spec.get("target") not in entities:
                error(
                    apath, f"{label}: input '{field}' ref target '{spec.get('target')}' not found"
                )
            elif spec["type"] == "enum" and not spec.get("values"):
                error(apath, f"{label}: input '{field}' enum needs values")


def _role_allows(role: str, allowed: list[str], roles: list[dict[str, Any]]) -> bool:
    inherits = {str(r.get("name")): list(r.get("inherits") or []) for r in roles}
    todo, seen = [role], set()
    while todo:
        current = todo.pop()
        if current in allowed:
            return True
        if current not in seen:
            seen.add(current)
            todo.extend(inherits.get(current, []))
    return False


# ----------------------------------------------------------------------------- shared


def json_schema(fields: dict[str, Any]) -> dict[str, Any]:
    props: dict[str, Any] = {}
    required = []
    for name, spec in fields.items():
        if not isinstance(spec, dict):
            continue
        t = spec.get("type")
        if t == "enum":
            schema: dict[str, Any] = {"type": "string", "enum": [str(v) for v in spec["values"]]}
        elif t == "ref":
            schema = {"type": "string", "description": f"id of {spec.get('target')}"}
        else:
            schema = dict(JSON_TYPES.get(str(t), {"type": "string"}))
        if spec.get("description"):
            schema["description"] = str(spec["description"])
        props[name] = schema
        if spec.get("required"):
            required.append(name)
    out: dict[str, Any] = {"type": "object", "properties": props, "additionalProperties": False}
    if required:
        out["required"] = required
    return out


def pascal(name: str) -> str:
    return name[:1].upper() + name[1:]


def snake(name: str) -> str:
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", name)
    return re.sub(r"([a-z\d])([A-Z])", r"\1_\2", s).replace("-", "_").lower()


def _js(value: Any, indent: int = 0) -> str:
    """Python value -> TypeScript literal (double quotes, trailing commas, 2-space indent)."""
    pad, inner = "  " * indent, "  " * (indent + 1)
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(value, (list, tuple)):
        if not value:
            return "[]"
        if all(isinstance(v, (str, int, float, bool)) for v in value):
            return "[" + ", ".join(_js(v) for v in value) + "]"
        return "[\n" + "".join(f"{inner}{_js(v, indent + 1)},\n" for v in value) + pad + "]"
    if isinstance(value, dict):
        if not value:
            return "{}"
        rows = []
        for k, v in value.items():
            key = k if re.fullmatch(r"[A-Za-z_$][\w$]*", k) else _js(k)
            rows.append(f"{inner}{key}: {_js(v, indent + 1)},\n")
        return "{\n" + "".join(rows) + pad + "}"
    return _js(str(value))


def _py(value: Any, indent: int = 0) -> str:
    """Python literal with stable formatting."""
    pad, inner = "    " * indent, "    " * (indent + 1)
    if isinstance(value, dict):
        if not value:
            return "{}"
        rows = "".join(f"{inner}{_py(k)}: {_py(v, indent + 1)},\n" for k, v in value.items())
        return "{\n" + rows + pad + "}"
    if isinstance(value, (list, tuple)):
        if not value:
            return "()"
        return "(" + ", ".join(_py(v) for v in value) + ("," if len(value) == 1 else "") + ")"
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return repr(value)


# ----------------------------------------------------------------------------- TypeScript


def gen_ts(root: Path, entities: dict[str, dict[str, Any]]) -> str:
    actions, roles, pii = load_actions(root), load_roles(root), pii_fields(entities)
    names = [str(r["name"]) for r in roles if r.get("name")]
    out = ["", "// ---- Roles, actions and personal data (ontology/roles.yaml, actions.yaml)", ""]
    out.append(
        "export type Role = " + (" | ".join(_js(n) for n in names) if names else "string") + ";"
    )
    out += ["", "export const ROLE_INHERITS: Readonly<Record<string, readonly Role[]>> = {"]
    for r in roles:
        out.append(f"  {_js(str(r['name']))}: {_js(list(r.get('inherits') or []))},")
    out += ["};", ""]
    out += [
        "/** Who runs an action, and as which role. */",
        "export interface ActionContext {",
        "  role: Role;",
        "  actor: string;",
        "}",
        "",
    ]
    for a in actions:
        fields = a.get("input") or {}
        out.append(f"export interface {pascal(str(a['name']))}Input {{")
        for fname, spec in fields.items():
            t = spec.get("type")
            ts = (
                " | ".join(_js(str(v)) for v in spec.get("values") or [])
                if t == "enum"
                else TS_TYPES.get(str(t), "string")
            )
            opt = "" if spec.get("required") else "?"
            note = f"id of {spec.get('target')}" if t == "ref" else spec.get("description")
            if note:
                out.append(f"  /** {note} */")
            out.append(f"  {fname}{opt}: {ts};")
        out += ["}", ""]
    out.append("/** Implement these in src/actions/ — one function per ontology action. */")
    out.append("export interface ActionHandlers {")
    for a in actions:
        output = str(a.get("output") or "")
        ret = f"{output.removesuffix('[]')}[]" if output.endswith("[]") else (output or "void")
        if a.get("description"):
            out.append(f"  /** {a['description']} */")
        out.append(
            f"  {a['name']}(input: {pascal(str(a['name']))}Input, ctx: ActionContext)"
            f": Promise<{ret}>;"
        )
    out += ["}", ""]
    out += [
        "export interface ActionSpec {",
        "  name: keyof ActionHandlers & string;",
        "  description: string;",
        "  entity: string | null;",
        '  kind: "create" | "update" | "delete" | "query" | "command";',
        "  roles: readonly Role[];",
        '  agent: "allowed" | "confirm" | "forbidden";',
        "  idempotent: boolean;",
        "  output: string | null;",
        "  inputSchema: Record<string, unknown>;",
        "}",
        "",
    ]
    specs = [
        {
            "name": str(a["name"]),
            "description": str(a.get("description") or ""),
            "entity": a.get("entity"),
            "kind": a.get("kind", "command"),
            "roles": list(a.get("roles") or []),
            "agent": a.get("agent", "forbidden"),
            "idempotent": bool(a.get("idempotent", False)),
            "output": a.get("output"),
            "inputSchema": json_schema(a.get("input") or {}),
        }
        for a in actions
    ]
    out.append(f"export const ACTIONS: readonly ActionSpec[] = {_js(specs)};")
    out += [
        "",
        "/** True if `role` (or a role it inherits) may run the action. */",
        "export function can(role: Role, action: ActionSpec): boolean {",
        '  if ((role as string) === "agent" && action.agent === "forbidden") return false;',
        "  const seen = new Set<string>();",
        "  const todo: string[] = [role];",
        "  while (todo.length > 0) {",
        "    const current = todo.pop() as string;",
        "    if ((action.roles as readonly string[]).includes(current)) return true;",
        "    if (seen.has(current)) continue;",
        "    seen.add(current);",
        "    todo.push(...(ROLE_INHERITS[current] ?? []));",
        "  }",
        "  return false;",
        "}",
        "",
        "/** Personal-data properties per entity (`pii: true` in the ontology). */",
        "export const PII_FIELDS: Readonly<Record<string, readonly string[]>> = "
        + _js({k: v for k, v in pii.items()})
        + ";",
        "",
        "/** Copy of `record` with personal data replaced: use before logging or agent output. */",
        "export function redactPII<T extends object>(entity: string, record: T): T {",
        "  const copy: Record<string, unknown> = { ...(record as Record<string, unknown>) };",
        "  for (const field of PII_FIELDS[entity] ?? []) {",
        '    if (field in copy) copy[field] = "[redacted]";',
        "  }",
        "  return copy as unknown as T;",
        "}",
    ]
    return "\n".join(out) + "\n"


# ----------------------------------------------------------------------------- Python


def gen_python(root: Path, entities: dict[str, dict[str, Any]]) -> tuple[list[str], str]:
    """Returns (extra imports, code block)."""
    actions, roles, pii = load_actions(root), load_roles(root), pii_fields(entities)
    names = [str(r["name"]) for r in roles if r.get("name")]
    imports = ["from dataclasses import dataclass", "from typing import Any, Literal, Protocol"]
    if any(
        (s or {}).get("type") in ("date", "datetime")
        for a in actions
        for s in (a.get("input") or {}).values()
    ):
        imports.insert(0, "import datetime")
    blocks: list[str] = []
    blocks.append("Role = " + (f"Literal[{', '.join(_py(n) for n in names)}]" if names else "str"))
    inherits = {str(r["name"]): tuple(r.get("inherits") or []) for r in roles}
    blocks.append(f"ROLE_INHERITS: dict[str, tuple[str, ...]] = {_py(inherits)}")
    blocks.append(
        "@dataclass(frozen=True)\nclass ActionContext:\n"
        '    """Who runs an action, and as which role."""\n\n'
        "    role: str\n    actor: str"
    )
    for a in actions:
        fields = a.get("input") or {}
        lines = [
            "@dataclass(frozen=True, kw_only=True)",
            f"class {pascal(str(a['name']))}Input:",
            f'    """Input of {a["name"]}."""',
        ]
        if fields:
            lines.append("")
        for fname, spec in fields.items():
            t = spec.get("type")
            py = (
                f"Literal[{', '.join(_py(str(v)) for v in spec.get('values') or [])}]"
                if t == "enum"
                else PY_TYPES.get(str(t), "str")
            )
            lines.append(
                f"    {snake(fname)}: {py}"
                if spec.get("required")
                else f"    {snake(fname)}: {py} | None = None"
            )
        blocks.append("\n".join(lines))
    proto = [
        "class ActionHandlers(Protocol):",
        '    """Implement in your package (one method per ontology action)."""',
    ]
    if actions:
        proto.append("")
    for i, a in enumerate(actions):
        output = str(a.get("output") or "")
        ret = f"list[{output.removesuffix('[]')}]" if output.endswith("[]") else (output or "None")
        if i:
            proto.append("")
        proto.append(
            f"    def {snake(str(a['name']))}(\n"
            f"        self, data: {pascal(str(a['name']))}Input, ctx: ActionContext\n"
            f"    ) -> {ret}: ..."
        )
    blocks.append("\n".join(proto))
    blocks.append(
        "@dataclass(frozen=True)\nclass ActionSpec:\n"
        "    name: str\n    method: str\n    description: str\n    entity: str | None\n"
        "    kind: str\n    roles: tuple[str, ...]\n    agent: str\n    idempotent: bool\n"
        "    output: str | None\n    input_type: type[Any]\n    fields: dict[str, str]\n"
        "    input_schema: dict[str, Any]"
    )
    specs = []
    for a in actions:
        fields = {f: snake(f) for f in (a.get("input") or {})}
        args = {
            "name": str(a["name"]),
            "method": snake(str(a["name"])),
            "description": str(a.get("description") or ""),
            "entity": a.get("entity"),
            "kind": a.get("kind", "command"),
            "roles": tuple(a.get("roles") or []),
            "agent": a.get("agent", "forbidden"),
            "idempotent": bool(a.get("idempotent", False)),
            "output": a.get("output"),
        }
        body = "".join(f"        {k}={_py(v, 2)},\n" for k, v in args.items())
        body += f"        input_type={pascal(str(a['name']))}Input,\n"
        body += f"        fields={_py(fields, 2)},\n"
        body += f"        input_schema={_py(json_schema(a.get('input') or {}), 2)},\n"
        specs.append("    ActionSpec(\n" + body + "    ),\n")
    blocks.append("ACTIONS: tuple[ActionSpec, ...] = (\n" + "".join(specs) + ")")
    blocks.append(
        "def can(role: str, action: ActionSpec) -> bool:\n"
        '    """True if `role` (or a role it inherits) may run the action."""\n'
        '    if role == "agent" and action.agent == "forbidden":\n'
        "        return False\n"
        "    todo, seen = [role], set()\n"
        "    while todo:\n"
        "        current = todo.pop()\n"
        "        if current in action.roles:\n"
        "            return True\n"
        "        if current not in seen:\n"
        "            seen.add(current)\n"
        "            todo.extend(ROLE_INHERITS.get(current, ()))\n"
        "    return False"
    )
    pii_py = {k: tuple(snake(f) for f in v) for k, v in pii.items()}
    blocks.append(f"PII_FIELDS: dict[str, tuple[str, ...]] = {_py(pii_py)}")
    blocks.append(
        "def redact_pii(entity: str, record: dict[str, Any]) -> dict[str, Any]:\n"
        '    """Copy of `record` with personal data replaced: use before logging or agents."""\n'
        "    fields = PII_FIELDS.get(entity, ())\n"
        '    return {k: ("[redacted]" if k in fields else v) for k, v in record.items()}'
    )
    return imports, "\n\n\n".join(blocks)
