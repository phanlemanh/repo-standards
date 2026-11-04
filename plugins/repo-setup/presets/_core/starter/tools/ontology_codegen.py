#!/usr/bin/env python3
"""Generate code from ontology/entities/*.yaml (vendored by repo-setup).

  python3 tools/ontology_codegen.py --lang ts --out src/generated/ontology.ts
  python3 tools/ontology_codegen.py --lang python --out src/app/ontology_types.py
  ... --check     exit 1 if the file is out of date (use in CI)

Generates, per entity: a type (TS interface / frozen Python dataclass), enum literal types,
and a predicate for every subtype whose rule is a simple comparison such as
"points >= 100" or "status == 'active' and points > 0".
Properties with `required: true` or a `default` are non-optional.
Never edit the output by hand: change the ontology and run `make gen`.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ontology_actions
from repo_ontology import find_repo_root, load_entities

HEADER = "Generated from ontology/ by tools/ontology_codegen.py. Do not edit: run `make gen`."
TS_TYPES = {
    "string": "string",
    "text": "string",
    "uuid": "string",
    "date": "string",
    "datetime": "string",
    "integer": "number",
    "number": "number",
    "boolean": "boolean",
    "ref": "string",
}
PY_TYPES = {
    "string": "str",
    "text": "str",
    "uuid": "str",
    "date": "datetime.date",
    "datetime": "datetime.datetime",
    "integer": "int",
    "number": "float",
    "boolean": "bool",
    "ref": "str",
}
COMPARISON = re.compile(
    r"^\s*([A-Za-z_]\w*)\s*(>=|<=|==|!=|>|<)\s*"
    r"(-?\d+(?:\.\d+)?|'[^']*'|\"[^\"]*\"|true|false)\s*$"
)


def snake(name: str) -> str:
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", name)
    s = re.sub(r"([a-z\d])([A-Z])", r"\1_\2", s)
    return s.replace("-", "_").lower()


def camel(name: str) -> str:
    parts = snake(name).split("_")
    return parts[0] + "".join(p.title() for p in parts[1:])


def is_required(spec: dict[str, Any]) -> bool:
    return bool(spec.get("required")) or "default" in spec


def parse_rule(rule: str) -> list[list[tuple[str, str, str]]] | None:
    """'a >= 1 and b == "x" or c' -> OR-list of AND-lists of (prop, op, literal)."""
    groups: list[list[tuple[str, str, str]]] = []
    for alt in re.split(r"\s+or\s+", rule.strip()):
        terms = []
        for part in re.split(r"\s+and\s+", alt):
            m = COMPARISON.match(part)
            if not m:
                return None
            terms.append((m.group(1), m.group(2), m.group(3)))
        groups.append(terms)
    return groups


def literal(value: str, lang: str) -> str:
    if value in ("true", "false"):
        return value if lang == "ts" else value.title()
    if value[0] in "'\"":
        return '"' + value[1:-1].replace('"', '\\"') + '"'
    return value


def entity_props(data: dict[str, Any]) -> dict[str, dict[str, Any]]:
    props = data.get("properties") or {}
    return {k: v for k, v in props.items() if isinstance(v, dict)}


def predicate_terms(
    rule: str, props: dict[str, dict[str, Any]]
) -> list[list[tuple[str, str, str]]] | str:
    groups = parse_rule(rule)
    if groups is None:
        return "rule is not a simple comparison"
    for terms in groups:
        for prop, _op, _lit in terms:
            if prop not in props:
                return f"unknown property '{prop}'"
            if not is_required(props[prop]):
                return f"property '{prop}' is optional"
    return groups


def gen_ts(entities: dict[str, dict[str, Any]]) -> str:
    out = [f"// {HEADER}", ""]
    if not entities:
        out += ["export {};", ""]
    for name, data in entities.items():
        props = entity_props(data)
        for pname, spec in props.items():
            if spec.get("type") == "enum":
                values = " | ".join('"' + str(v) + '"' for v in spec.get("values") or [])
                out += [f"export type {name}{pname[0].upper()}{pname[1:]} = {values};", ""]
        if data.get("description"):
            out.append(f"/** {data['description']} */")
        out.append(f"export interface {name} {{")
        for pname, spec in props.items():
            ptype = spec.get("type")
            ts = (
                f"{name}{pname[0].upper()}{pname[1:]}"
                if ptype == "enum"
                else TS_TYPES.get(str(ptype), "unknown")
            )
            notes = []
            if spec.get("description"):
                notes.append(str(spec["description"]))
            if ptype == "ref":
                notes.append(f"id of {spec.get('target')}")
            if ptype in ("date", "datetime"):
                notes.append(f"ISO {ptype}")
            if notes:
                out.append(f"  /** {'; '.join(notes)} */")
            optional = "" if is_required(spec) else "?"
            out.append(f"  {pname}{optional}: {ts};")
        out += ["}", ""]
        for sub, sspec in (data.get("subtypes") or {}).items():
            rule = (sspec or {}).get("rule")
            if not rule:
                continue
            terms = predicate_terms(str(rule), props)
            if isinstance(terms, str):
                out += [f"// {sub}: predicate not generated ({terms}): {rule}", ""]
                continue
            ops = {"==": "===", "!=": "!=="}
            expr = " || ".join(
                "("
                + " && ".join(f"e.{p} {ops.get(o, o)} {literal(lit, 'ts')}" for p, o, lit in t)
                + ")"
                if len(terms) > 1
                else " && ".join(f"e.{p} {ops.get(o, o)} {literal(lit, 'ts')}" for p, o, lit in t)
                for t in terms
            )
            desc = (sspec or {}).get("description") or rule
            out += [
                f"/** {desc} */",
                f"export function is{sub}(e: {name}): boolean {{",
                f"  return {expr};",
                "}",
                "",
            ]
    return "\n".join(out).rstrip("\n") + "\n"


def gen_python(
    entities: dict[str, dict[str, Any]], extra: tuple[list[str], str] | None = None
) -> str:
    uses_dt = any(
        spec.get("type") in ("date", "datetime")
        for d in entities.values()
        for spec in entity_props(d).values()
    )
    uses_enum = any(
        spec.get("type") == "enum" for d in entities.values() for spec in entity_props(d).values()
    )
    imports = ["from __future__ import annotations"]
    third = []
    extra_imports = extra[0] if extra else []
    if uses_dt or "import datetime" in extra_imports:
        third.append("import datetime")
    if entities or extra:
        third.append("from dataclasses import dataclass")
    typing_names = set()
    if uses_enum:
        typing_names.add("Literal")
    for line in extra_imports:
        if line.startswith("from typing import "):
            typing_names.update(n.strip() for n in line[len("from typing import ") :].split(","))
    if typing_names:
        third.append("from typing import " + ", ".join(sorted(typing_names)))
    if third:
        imports += ["", *third]
    # (kind, lines): "stmt" = module-level assignment, "def" = class/function/comment
    blocks: list[tuple[str, list[str]]] = []
    for name, data in entities.items():
        props = entity_props(data)
        for pname, spec in props.items():
            if spec.get("type") == "enum":
                values = ", ".join('"' + str(v) + '"' for v in spec.get("values") or [])
                alias = f"{name}{pname[0].upper()}{pname[1:]} = Literal[{values}]"
                blocks.append(("stmt", [alias]))
        out: list[str] = ["@dataclass(frozen=True, kw_only=True)", f"class {name}:"]
        blocks.append(("def", out))
        out.append(f'    """{data.get("description") or name}"""')
        if props:
            out.append("")
        for pname, spec in props.items():
            ptype = spec.get("type")
            py = (
                f"{name}{pname[0].upper()}{pname[1:]}"
                if ptype == "enum"
                else PY_TYPES.get(str(ptype), "object")
            )
            field = snake(pname)
            if is_required(spec):
                default = spec.get("default")
                if default is None:
                    out.append(f"    {field}: {py}")
                else:
                    out.append(f"    {field}: {py} = {py_literal(default)}")
            else:
                out.append(f"    {field}: {py} | None = None")
        for sub, sspec in (data.get("subtypes") or {}).items():
            rule = (sspec or {}).get("rule")
            if not rule:
                continue
            terms = predicate_terms(str(rule), props)
            if isinstance(terms, str):
                blocks.append(("def", [f"# {sub}: predicate not generated ({terms}): {rule}"]))
                continue
            expr = " or ".join(
                ("(" if len(terms) > 1 and len(t) > 1 else "")
                + " and ".join(f"e.{snake(p)} {o} {literal(lit, 'py')}" for p, o, lit in t)
                + (")" if len(terms) > 1 and len(t) > 1 else "")
                for t in terms
            )
            desc = (sspec or {}).get("description") or rule
            blocks.append(
                (
                    "def",
                    [
                        f"def is_{snake(sub)}(e: {name}) -> bool:",
                        f'    """{desc}"""',
                        f"    return {expr}",
                    ],
                )
            )
    if extra:
        blocks.append(("def", extra[1].split("\n")))
    lines = [f'"""{HEADER}"""', "", *imports]
    prev = "import"
    for kind, block in blocks:
        gap = 1 if kind == "stmt" and prev in ("import", "stmt") else 2
        lines += [""] * gap + block
        prev = kind
    return "\n".join(lines) + "\n"


def py_literal(value: Any) -> str:
    if isinstance(value, bool):
        return "True" if value else "False"
    if isinstance(value, (int, float)):
        return repr(value)
    return '"' + str(value).replace('"', '\\"') + '"'


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--lang", choices=["ts", "python"], required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--root", default=None)
    ap.add_argument("--check", action="store_true", help="fail if --out is out of date")
    args = ap.parse_args(argv)
    root = Path(args.root).resolve() if args.root else find_repo_root()
    entities = load_entities(root)
    # Always emitted (even when empty) so code using roles/actions/PII helpers compiles.
    extra = True
    if args.lang == "ts":
        code = gen_ts(entities)
        if extra:
            code = code.replace("export {};\n", "") + ontology_actions.gen_ts(root, entities)
    else:
        code = gen_python(entities, ontology_actions.gen_python(root, entities) if extra else None)
    out = root / args.out
    if args.check:
        current = out.read_text(encoding="utf-8") if out.exists() else None
        if current != code:
            print(f"{args.out} is out of date with ontology/. Run: make gen", file=sys.stderr)
            return 1
        print(f"{args.out} is up to date ({len(entities)} entities)")
        return 0
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(code, encoding="utf-8")
    print(f"wrote {args.out} ({len(entities)} entities)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
