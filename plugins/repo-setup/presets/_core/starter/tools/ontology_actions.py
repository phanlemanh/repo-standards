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
        own: [staff]                   # these roles only on what they hold (needs an own relation)
        sets: [total]                  # properties it sets; default: input fields of the same name
        relations: { places: [attach] }   # what it does to a relation: attach | detach | reassign

Entity properties may carry `pii: true` (personal data): generated helpers redact them in
anything returned to agents or written to logs.

ontology/entities/<Name>.yaml — `lifecycle:` records what the actions do not cover. Once a repo
declares actions, each entity needs a create, query, update and delete action, or a choice:
    lifecycle:
      update: { later: "Roadmap row 12" }                        # planned: listed on every run
      delete: { never: "Kept for the accounts", decided_by: "Lan, 2026-01-05" }   # a person decided
    lifecycle: { via: Order }                                    # handled through another entity
Each property is set by a create or update action, or the entity says why not:
    not_set:
      system: [id, createdAt]                                    # the system writes them
      import: [externalCode]                                     # only an import writes them
      later: { phone: "Roadmap row 12" }
      never: { points: { reason: "Only orders earn points", decided_by: "Lan, 2026-01-05" } }

ontology/relations.yaml — a relation marked `own: true` is what "own" means for the entities it
joins. Each relation answers attach, detach and reassign: an action that names it under
`relations:`, or a choice on the relation itself:
    - from: Member
      name: keeps
      to: Listing
      own: true
      lifecycle:
        reassign: { later: "Roadmap row 14" }                   # or { never: ..., decided_by: ... }
    lifecycle: { via: Order }             # set when the order is created, gone with it, never moved
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from repo_ontology import load_yaml_file

KINDS = {"create", "update", "delete", "query", "command"}
LIFECYCLE = ("create", "query", "update", "delete")
RELATION_OPS = ("attach", "detach", "reassign")
NOT_SET = ("system", "import", "later", "never")
DECIDED_BY = "'never' needs decided_by: the person who decided, never the agent that wrote the file"
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


def load_relations(root: Path) -> list[dict[str, Any]]:
    data = load_yaml_file(root / "ontology" / "relations.yaml") or {}
    items = data.get("relations") if isinstance(data, dict) else None
    return [r for r in (items or []) if isinstance(r, dict)]


def own_roles(action: dict[str, Any]) -> list[str]:
    """Roles that may run the action only on what they hold: `own: [role]`, or the
    permission-table form `scope: {role: own}`."""
    roles = [str(r) for r in _as_list(action.get("own"))]
    scope = action.get("scope")
    if isinstance(scope, dict):
        roles += [str(r) for r, s in scope.items() if s == "own" and str(r) not in roles]
    return roles


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
            error(
                apath,
                f"{label}: lists role 'agent' but agents are forbidden: "
                "set agent: allowed or confirm, or remove the role",
            )
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
    lint_lifecycle(root, entities, error, warn)
    lint_relations(root, entities, error, warn)
    lint_properties(root, entities, error, warn)


def lint_lifecycle(root: Path, entities: dict[str, dict[str, Any]], error: Any, warn: Any) -> None:
    """Once a repo declares actions, every entity answers create / query / update / delete:
    an action of that kind, or a choice recorded under `lifecycle:` in the entity file."""
    actions = load_actions(root)
    if not actions:
        return
    covered: dict[tuple[str, str], str] = {}
    for a in actions:
        key = (str(a.get("entity") or ""), str(a.get("kind") or "command"))
        covered.setdefault(key, str(a.get("name") or ""))
    for name, data in entities.items():
        path = f"ontology/entities/{name}.yaml"
        life = data.get("lifecycle")
        if life is None:
            life = {}
        if not isinstance(life, dict):
            error(path, "lifecycle must be a mapping: {via: <Entity>} or one entry per operation")
            continue
        for key in life:
            if key != "via" and key not in LIFECYCLE:
                allowed = ", ".join(("via", *LIFECYCLE))
                error(path, f"lifecycle.{key}: unknown key (use one of: {allowed})")
        if "via" in life:
            via = life["via"]
            if via == name:
                error(path, "lifecycle.via: an entity cannot be handled through itself")
            elif via not in entities:
                error(path, f"lifecycle.via: '{via}' is not an entity")
            continue
        for kind in LIFECYCLE:
            action, entry = covered.get((name, kind)), life.get(kind)
            if entry is None:
                if not action:
                    error(
                        path,
                        f"no '{kind}' action for {name}: add one to ontology/actions.yaml "
                        f"(entity: {name}, kind: {kind}), or record the choice here as "
                        f"lifecycle.{kind}: {{later: <where it is planned>}} or "
                        "{never: <reason>, decided_by: <the person who decided>}",
                    )
                continue
            if action:
                stale = f"lifecycle.{kind} is out of date: {action} now does it, remove the entry"
                warn(path, stale)
            problem = _choice_problem(entry)
            if problem:
                error(path, f"lifecycle.{kind}: {problem}")
            elif entry.get("later") and not action:
                warn(path, f"{name}: '{kind}' is planned, not built ({entry['later']})")


def _choice_problem(entry: Any) -> str | None:
    """What is wrong with a recorded choice: {later: ...} or {never: ..., decided_by: ...}."""
    if not isinstance(entry, dict) or bool(entry.get("later")) == bool(entry.get("never")):
        return "give either later: <where> or never: <reason>"
    if entry.get("never") and not entry.get("decided_by"):
        return DECIDED_BY
    return None


def _as_list(value: Any) -> list[Any]:
    if value is None:
        return []
    return list(value) if isinstance(value, (list, tuple)) else [value]


def _is_names(value: Any) -> bool:
    return isinstance(value, list) and all(isinstance(v, str) for v in value)


def _handled_through(name: str, entities: dict[str, dict[str, Any]]) -> list[str]:
    """The entity, then every entity it is handled through (lifecycle.via), nearest first."""
    chain = [name]
    while True:
        life = (entities.get(chain[-1]) or {}).get("lifecycle")
        via = life.get("via") if isinstance(life, dict) else None
        if via not in entities or via in chain:
            return chain
        chain.append(via)


def lint_relations(root: Path, entities: dict[str, dict[str, Any]], error: Any, warn: Any) -> None:
    """Once a repo declares actions: an action a role runs only on its "own" records needs a
    relation marked `own: true` that says what "own" means, and every relation answers attach /
    detach / reassign: an action that names it, or a choice under `lifecycle:` on the relation."""
    actions = load_actions(root)
    if not actions:
        return
    apath, rpath = "ontology/actions.yaml", "ontology/relations.yaml"
    relations = load_relations(root)
    by_name: dict[str, list[dict[str, Any]]] = {}
    for r in relations:
        by_name.setdefault(str(r.get("name") or ""), []).append(r)

    done: dict[tuple[int, str], str] = {}  # (relation, operation) -> the action that does it
    for a in actions:
        label, links = f"action '{a.get('name')}'", a.get("relations")
        if links is None:
            continue
        if not isinstance(links, dict):
            error(
                apath,
                f"{label}: relations must be a mapping of relation name -> "
                f"{', '.join(RELATION_OPS)}",
            )
            continue
        for rname, ops in links.items():
            found = by_name.get(str(rname), [])
            if not found:
                error(apath, f"{label}: relation '{rname}' is not in {rpath}")
            elif len(found) > 1:
                error(
                    apath,
                    f"{label}: relation '{rname}' is the name of {len(found)} relations: "
                    "give each its own name",
                )
            for op in _as_list(ops):
                if op not in RELATION_OPS:
                    allowed = ", ".join(RELATION_OPS)
                    error(
                        apath,
                        f"{label}: relation '{rname}': unknown operation '{op}' "
                        f"(use one of: {allowed})",
                    )
                elif len(found) == 1:
                    done.setdefault((id(found[0]), op), str(a.get("name") or ""))

    own_ends: set[str] = set()
    for r in relations:
        label = f"{r.get('from')} -{r.get('name')}-> {r.get('to')}"
        if "own" in r and not isinstance(r["own"], bool):
            error(rpath, f"{label}: own must be true or false")
        elif r.get("own"):
            own_ends.update((str(r.get("from")), str(r.get("to"))))
        acted = {op: done[(id(r), op)] for op in RELATION_OPS if (id(r), op) in done}
        _lint_relation_changes(r, label, acted, error, warn)

    for a in actions:
        roles = own_roles(a)
        if not roles:
            continue
        label, ent = f"action '{a.get('name')}'", a.get("entity")
        for role in _as_list(a.get("own")):
            if role not in (a.get("roles") or []):
                error(apath, f"{label}: own lists role '{role}', which is not in its roles")
        if not ent:
            error(apath, f"{label}: own needs entity: the thing a role may hold")
        elif ent in entities and not own_ends.intersection(_handled_through(ent, entities)):
            error(
                apath,
                f"{label}: {', '.join(roles)} may run it only on their own {ent}, but no relation "
                f"says what 'own' means: add a relation between the entity that holds the role "
                f"and {ent} to {rpath} and mark it own: true (a relation to the entity {ent} is "
                "handled through, lifecycle.via, counts too)",
            )


def _lint_relation_changes(
    r: dict[str, Any], label: str, acted: dict[str, str], error: Any, warn: Any
) -> None:
    rpath = "ontology/relations.yaml"
    life = r.get("lifecycle")
    if life is None:
        life = {}
    if not isinstance(life, dict):
        error(
            rpath,
            f"{label}: lifecycle must be a mapping: {{via: <Entity>}} or one entry per operation",
        )
        return
    for key in life:
        if key != "via" and key not in RELATION_OPS:
            allowed = ", ".join(("via", *RELATION_OPS))
            error(rpath, f"{label}: lifecycle.{key}: unknown key (use one of: {allowed})")
    if "via" in life:
        if life["via"] not in (r.get("from"), r.get("to")):
            error(
                rpath,
                f"{label}: lifecycle.via: '{life['via']}' is not one of its ends "
                f"({r.get('from')}, {r.get('to')})",
            )
        for op, doer in acted.items():
            error(
                rpath,
                f"{label}: lifecycle.via says the link never changes, but {doer} does "
                f"'{op}': remove via and answer each operation",
            )
        return
    missing = []
    for op in RELATION_OPS:
        action, entry = acted.get(op), life.get(op)
        if entry is None:
            # many-to-many: moving a link is a detach and an attach, not a third operation
            asked = op != "reassign" or r.get("cardinality") != "many-to-many"
            if asked and not action:
                missing.append(op)
            continue
        if action:
            stale = (
                f"{label}: lifecycle.{op} is out of date: {action} now does it, remove the entry"
            )
            warn(rpath, stale)
        problem = _choice_problem(entry)
        if problem:
            error(rpath, f"{label}: lifecycle.{op}: {problem}")
        elif entry.get("later") and not action:
            warn(rpath, f"{label}: '{op}' is planned, not built ({entry['later']})")
    if missing:
        error(
            rpath,
            f"{label}: no answer for {', '.join(missing)}: for each, add "
            f"relations: {{{r.get('name')}: [<operation>]}} to the action that does it in "
            "ontology/actions.yaml, or record the choice on the relation as "
            "lifecycle.<operation>: {later: <where it is planned>} or "
            "{never: <reason>, decided_by: <the person who decided>}. A link that is set when "
            "one end is created and never changes is one line: lifecycle: {via: <that entity>}",
        )


def lint_properties(root: Path, entities: dict[str, dict[str, Any]], error: Any, warn: Any) -> None:
    """Once a repo declares actions, every property of an entity that has a create or update
    action is set by one (`sets: [...]`, or an input field of the same name), or the entity says
    why not under `not_set:`."""
    actions = load_actions(root)
    if not actions:
        return
    apath = "ontology/actions.yaml"
    set_by: dict[str, dict[str, str]] = {}  # entity -> property -> the action that sets it
    written: set[str] = set()  # entities with a create or update action
    for a in actions:
        aname, ent, kind = str(a.get("name") or ""), a.get("entity"), a.get("kind", "command")
        label = f"action '{aname}'"
        props = (entities.get(ent) or {}).get("properties") if ent in entities else None
        props = props if isinstance(props, dict) else {}
        if ent and kind in ("create", "update"):
            written.add(ent)
        if "sets" not in a:
            names = [f for f in (a.get("input") or {}) if kind in ("create", "update")]
        elif not _is_names(a["sets"]):
            error(apath, f"{label}: sets must be a list of property names")
            continue
        elif not ent:
            error(apath, f"{label}: sets needs entity: the thing whose properties it sets")
            continue
        else:
            names = a["sets"]
            for p in names if ent in entities else []:
                if p not in props:
                    error(apath, f"{label}: sets '{p}', which is not a property of {ent}")
        for p in names:
            if p in props:
                set_by.setdefault(str(ent), {}).setdefault(str(p), aname)

    for name, data in entities.items():
        path = f"ontology/entities/{name}.yaml"
        props = data.get("properties")
        props = props if isinstance(props, dict) else {}
        setters = set_by.get(name, {})
        recorded = _lint_not_set(name, path, data.get("not_set"), props, setters, error, warn)
        life = data.get("lifecycle")
        if name not in written or (isinstance(life, dict) and "via" in life):
            continue
        missing = [p for p in props if p not in setters and p not in recorded]
        if missing:
            error(
                path,
                f"{name}: no create or update action sets {', '.join(missing)}: name them in an "
                "action in ontology/actions.yaml (sets: [...], or an input field of the same "
                "name), or record why here under not_set: system: [...] when the system writes "
                "them, import: [...] when only an import does, "
                "later: {<property>: <where it is planned>} or "
                "never: {<property>: {reason: <why>, decided_by: <the person who decided>}}",
            )


def _lint_not_set(
    name: str,
    path: str,
    block: Any,
    props: dict[str, Any],
    setters: dict[str, str],
    error: Any,
    warn: Any,
) -> set[str]:
    """Check an entity's `not_set:` block; return the properties it accounts for."""
    recorded: set[str] = set()
    if block is None:
        return recorded
    if not isinstance(block, dict):
        error(path, f"not_set must be a mapping with any of: {', '.join(NOT_SET)}")
        return recorded
    planned: dict[str, list[str]] = {}  # where it is planned -> properties
    for key, value in block.items():
        if key not in NOT_SET:
            error(path, f"not_set.{key}: unknown key (use one of: {', '.join(NOT_SET)})")
            continue
        if key in ("system", "import"):
            if not _is_names(value):
                error(path, f"not_set.{key} must be a list of property names")
                continue
            entries: dict[Any, Any] = dict.fromkeys(value)
        elif not isinstance(value, dict):
            shape = "<where it is planned>" if key == "later" else "{reason: ..., decided_by: ...}"
            error(path, f"not_set.{key} must be a mapping of property -> {shape}")
            continue
        else:
            entries = value
        for p, entry in entries.items():
            if p not in props:
                error(path, f"not_set.{key}: '{p}' is not a property of {name}")
                continue
            recorded.add(p)
            if p in setters:
                warn(
                    path,
                    f"not_set.{key}: '{p}' is out of date: {setters[p]} now sets it, remove it",
                )
            if key == "later" and not entry:
                error(path, f"not_set.later.{p}: say where it is planned")
            elif key == "later" and p not in setters:
                planned.setdefault(str(entry), []).append(p)
            elif key == "never" and not (isinstance(entry, dict) and entry.get("reason")):
                error(path, f"not_set.never.{p}: give reason: <why> and decided_by: <person>")
            elif key == "never" and not entry.get("decided_by"):
                error(path, f"not_set.never.{p}: {DECIDED_BY}")
    for where, names in planned.items():
        warn(path, f"{name}: setting {', '.join(names)} is planned, not built ({where})")
    return recorded


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
