#!/usr/bin/env python3
"""Read and check setup-blueprint.yaml, the record of the decisions taken during setup.

  blueprint.py check FILE             print problems, exit 1 if there are any
  blueprint.py dependents LAYER       layers to look at again when LAYER changes
  blueprint.py not-applicable PRESET  layers that do not apply to that stack, with the reason

The blueprint records one setup session. Afterwards .repo-setup.json is the truth about what was
applied: changing a decision later is manual work, because apply.py only ever adds files.
Standard library only (the YAML reader is the plugin's own).
"""

from __future__ import annotations

import sys

if sys.version_info < (3, 11):
    sys.exit("repo-setup needs Python 3.11 or newer; this is " + sys.version.split()[0])

import tomllib
from pathlib import Path
from typing import Any

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
CORE_TOOLS = PLUGIN_ROOT / "presets" / "_core" / "starter" / "tools"
LAYERS_FILE = PLUGIN_ROOT / "skills" / "new" / "references" / "layers.toml"

STATUSES = {"designing", "approved", "applied"}
LAYER_STATUSES = {"pending", "decided", "needs_review", "not_applicable"}
AUTOMATION = {"automated", "partial", "manual"}
AI_TIERS = {"none", "call", "workflow", "agent"}
AGENT_RUNTIMES = {"tool-runner", "manual-loop", "agent-sdk", "managed-agents"}


def _layers() -> list[dict[str, Any]]:
    with LAYERS_FILE.open("rb") as fh:
        return list(tomllib.load(fh)["layer"])


LAYERS: tuple[str, ...] = tuple(str(layer["id"]) for layer in _layers())


def not_applicable(preset: str | None) -> dict[str, str]:
    """Layers that do not apply to a stack preset, with the reason to show the user."""
    return {
        str(layer["id"]): str(layer["not_applicable"][preset])
        for layer in _layers()
        if preset and preset in (layer.get("not_applicable") or {})
    }


def _preset(layers: dict[str, Any]) -> str | None:
    stack = layers.get("stack")
    choice = stack.get("choice") if isinstance(stack, dict) else None
    return choice.get("preset") if isinstance(choice, dict) else None


def load(path: Path) -> dict[str, Any]:
    sys.path.insert(0, str(CORE_TOOLS))
    from repo_ontology import load_yaml_file

    data = load_yaml_file(path)
    if not isinstance(data, dict):
        raise ValueError(f"{path} is not a mapping")
    return data


def errors(bp: dict[str, Any]) -> list[str]:
    problems = []
    if bp.get("status") not in STATUSES:
        problems.append(f"status must be one of {sorted(STATUSES)}")
    layers = bp.get("layers")
    if not isinstance(layers, dict):
        return [*problems, "layers must be a mapping"]
    skip = not_applicable(_preset(layers))
    for name, layer in layers.items():
        if name not in LAYERS:
            problems.append(f"unknown layer: {name}")
            continue
        if not isinstance(layer, dict):
            problems.append(f"{name}: must be a mapping")
            continue
        if layer.get("status") not in LAYER_STATUSES:
            problems.append(f"{name}: status must be one of {sorted(LAYER_STATUSES)}")
        if "automation" in layer and layer["automation"] not in AUTOMATION:
            problems.append(f"{name}: automation must be one of {sorted(AUTOMATION)}")
        if layer.get("status") == "decided":
            if not layer.get("why"):
                problems.append(f"{name}: a decided layer needs a why")
            if "automation" not in layer:
                problems.append(f"{name}: a decided layer needs automation")
        if name == "ai":
            problems += _ai_errors(layer)
        # Nothing may be built for a layer that does not apply to the chosen stack. A `manual`
        # note is fine: it is only recorded.
        if name in skip and layer.get("status") == "decided" and layer.get("automation") != "manual":
            problems.append(
                f"{name}: not applicable with preset {_preset(layers)} ({skip[name]}) "
                "Set status: not_applicable and give this reason as why."
            )
    return problems


def _ai_errors(layer: dict[str, Any]) -> list[str]:
    choice = layer.get("choice") or {}
    tier, runtime = choice.get("ai_tier"), choice.get("agent_runtime")
    problems = []
    if tier is not None and tier not in AI_TIERS:
        problems.append(f"ai: ai_tier must be one of {sorted(AI_TIERS)}")
    if runtime is not None and runtime not in AGENT_RUNTIMES:
        problems.append(f"ai: agent_runtime must be one of {sorted(AGENT_RUNTIMES)}")
    if runtime not in (None, "tool-runner") and layer.get("automation") != "manual":
        problems.append(f"ai: agent_runtime {runtime} is not generated, so automation must be manual")
    return problems


def blocking(bp: dict[str, Any]) -> list[str]:
    """Layers still waiting for a decision. A layer that is not listed counts as pending."""
    layers = bp.get("layers") or {}
    return [
        name
        for name in LAYERS
        if (layers.get(name) or {}).get("status", "pending") in ("pending", "needs_review")
    ]


def _choices(bp: dict[str, Any]) -> dict[str, Any]:
    """Choices of the layers that apply.py can carry out."""
    merged: dict[str, Any] = {}
    for name, layer in (bp.get("layers") or {}).items():
        if (
            isinstance(layer, dict)
            and layer.get("status") == "decided"
            and layer.get("automation") in ("automated", "partial")
        ):
            merged[name] = layer.get("choice") or {}
    return merged


def expected_setup(bp: dict[str, Any]) -> dict[str, Any]:
    """What .repo-setup.json should say after applying this blueprint."""
    c = _choices(bp)
    caps = list((c.get("governance") or {}).get("capabilities") or [])
    tier = (c.get("ai") or {}).get("ai_tier")
    if tier and tier != "none":
        caps.append("ai")
    return {
        "preset": (c.get("stack") or {}).get("preset"),
        "level": (c.get("quality") or {}).get("level"),
        "archetype": (c.get("architecture") or {}).get("archetype"),
        "deploy": (c.get("delivery") or {}).get("deploy"),
        "capabilities": caps,
    }


def to_apply_args(bp: dict[str, Any]) -> list[str]:
    c = _choices(bp)
    want = expected_setup(bp)
    args: list[str] = []
    for key in ("preset", "level", "archetype", "deploy"):
        if want[key]:
            args += [f"--{key}", str(want[key])]
    if want["capabilities"]:
        args += ["--with", ",".join(str(cap) for cap in want["capabilities"])]
    variables: dict[str, Any] = {
        k: bp.get(k) for k in ("conversation_language", "docs_language") if bp.get(k)
    }
    context = c.get("context") or {}
    for key in ("project_name", "description", "owner"):
        if context.get(key):
            variables[key] = context[key]
    if (c.get("repo") or {}).get("license"):
        variables["license"] = c["repo"]["license"]
    if (c.get("governance") or {}).get("marketplace"):
        variables["marketplace"] = c["governance"]["marketplace"]
    tier = (c.get("ai") or {}).get("ai_tier")
    if tier and tier != "none":
        variables["ai_tier"] = tier
    # Stack claude-plugin: the sample plugin's name, and whether plugins share one version.
    for key in ("plugin_name", "plugin_versioning"):
        if (c.get("stack") or {}).get(key):
            variables[key] = c["stack"][key]
    for key, value in variables.items():
        args += ["--var", f"{key}={value}"]
    return args


def dependents(layer: str) -> list[str]:
    """Layers that depend on `layer`, directly or not, in visiting order."""
    if layer not in LAYERS:
        raise ValueError(f"unknown layer: {layer}")
    needs = {str(item["id"]): set(item["depends_on"]) for item in _layers()}
    found = {layer}
    for name in LAYERS:
        if needs[name] & found:
            found.add(name)
    return [name for name in LAYERS if name in found and name != layer]


def manual_steps(bp: dict[str, Any]) -> list[str]:
    steps: list[str] = []
    for layer in (bp.get("layers") or {}).values():
        if isinstance(layer, dict):
            steps += [str(step) for step in layer.get("manual_steps") or []]
    return steps


def drift(bp: dict[str, Any], setup: dict[str, Any]) -> list[str]:
    """Differences between the blueprint and what was applied. An agent tier also brings mcp, so
    the applied capabilities may be a superset."""
    want = expected_setup(bp)
    found = []
    for key in ("preset", "level", "archetype", "deploy"):
        if want[key] and want[key] != setup.get(key):
            found.append(f"{key}: blueprint says {want[key]}, repo has {setup.get(key)}")
    missing = set(want["capabilities"]) - set(setup.get("capabilities") or [])
    if missing:
        found.append(f"capabilities missing from the repo: {', '.join(sorted(missing))}")
    return found


def main(argv: list[str]) -> int:
    if len(argv) == 2 and argv[0] == "check":
        try:
            problems = errors(load(Path(argv[1])))
        except (OSError, ValueError) as exc:
            problems = [str(exc)]
        for problem in problems:
            print(problem)
        return 1 if problems else 0
    if len(argv) == 2 and argv[0] == "dependents":
        print(" ".join(dependents(argv[1])))
        return 0
    if len(argv) == 2 and argv[0] == "not-applicable":
        for name, reason in not_applicable(argv[1]).items():
            print(f"{name}: {reason}")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
