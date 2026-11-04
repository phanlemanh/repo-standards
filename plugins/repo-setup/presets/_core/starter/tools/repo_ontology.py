"""Shared helpers for the ontology/ and wiki/ tools (vendored by repo-setup).

Reads the YAML used in ontology/ files and wiki front matter. Uses PyYAML when it is
installed; otherwise falls back to a small built-in parser that supports the subset these
files use: block mappings and sequences, inline [lists] and {maps}, quoted and plain
scalars, comments, and | / > block strings. Standard library only.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

try:  # pragma: no cover - depends on the environment
    import yaml as _pyyaml
except ImportError:  # pragma: no cover
    _pyyaml = None

_INT = re.compile(r"^[-+]?\d+$")
_FLOAT = re.compile(r"^[-+]?(\d+\.\d*|\.\d+|\d+)([eE][-+]?\d+)?$")
_KEY = re.compile(r"""^(?P<key>"[^"]*"|'[^']*'|[^\s"'#\[\]{},][^:#]*?)\s*:(?:\s+(?P<rest>.*))?$""")


class YamlError(ValueError):
    pass


def parse_yaml(text: str) -> Any:
    if _pyyaml is not None:
        try:
            return _pyyaml.safe_load(text)
        except _pyyaml.YAMLError as exc:
            raise YamlError(str(exc)) from exc
    return _MiniYaml(text).parse()


def _strip_comment(line: str) -> str:
    quote = ""
    for i, ch in enumerate(line):
        if quote:
            if ch == quote:
                quote = ""
        elif ch in "\"'" and (i == 0 or line[i - 1] in " \t[{,:-"):
            quote = ch
        elif ch == "#" and (i == 0 or line[i - 1] in " \t"):
            return line[:i]
    return line


def _scalar(s: str) -> Any:
    s = s.strip()
    if s == "" or s in ("~", "null", "Null", "NULL"):
        return None
    if s in ("true", "True", "TRUE"):
        return True
    if s in ("false", "False", "FALSE"):
        return False
    if len(s) >= 2 and s[0] == s[-1] == '"':
        try:
            return str(json.loads(s))
        except json.JSONDecodeError:
            return s[1:-1]
    if len(s) >= 2 and s[0] == s[-1] == "'":
        return s[1:-1].replace("''", "'")
    if _INT.match(s):
        return int(s)
    if _FLOAT.match(s) and any(c.isdigit() for c in s):
        return float(s)
    return s


def _flow(s: str) -> Any:
    value, j = _flow_value(s, 0)
    if s[j:].strip():
        raise YamlError(f"unexpected text after flow value: {s[j:]!r}")
    return value


def _ws(s: str, j: int) -> int:
    while j < len(s) and s[j] in " \t":
        j += 1
    return j


def _flow_value(s: str, j: int) -> tuple[Any, int]:
    j = _ws(s, j)
    if j >= len(s):
        return None, j
    c = s[j]
    if c == "[":
        items: list[Any] = []
        j += 1
        while True:
            j = _ws(s, j)
            if j < len(s) and s[j] == "]":
                return items, j + 1
            v, j = _flow_value(s, j)
            items.append(v)
            j = _ws(s, j)
            if j < len(s) and s[j] == ",":
                j += 1
            elif j < len(s) and s[j] == "]":
                return items, j + 1
            else:
                raise YamlError(f"bad flow list: {s!r}")
    if c == "{":
        obj: dict[str, Any] = {}
        j += 1
        while True:
            j = _ws(s, j)
            if j < len(s) and s[j] == "}":
                return obj, j + 1
            k_end = s.find(":", j)
            if k_end < 0:
                raise YamlError(f"bad flow map: {s!r}")
            key = _scalar(s[j:k_end])
            v, j = _flow_value(s, k_end + 1)
            obj[str(key)] = v
            j = _ws(s, j)
            if j < len(s) and s[j] == ",":
                j += 1
            elif j < len(s) and s[j] == "}":
                return obj, j + 1
            else:
                raise YamlError(f"bad flow map: {s!r}")
    if c in "\"'":
        end = j + 1
        while end < len(s):
            if s[end] == c and not (c == "'" and end + 1 < len(s) and s[end + 1] == "'"):
                break
            end += 2 if (c == "'" and s[end] == "'") or (c == '"' and s[end] == "\\") else 1
        return _scalar(s[j : end + 1]), end + 1
    end = j
    while end < len(s) and s[end] not in ",]}":
        end += 1
    return _scalar(s[j:end]), end


def _value(rest: str) -> Any:
    rest = rest.strip()
    if rest.startswith(("[", "{")):
        return _flow(rest)
    return _scalar(rest)


class _MiniYaml:
    def __init__(self, text: str) -> None:
        self.lines: list[tuple[int, str, str]] = []  # (indent, content, raw)
        for raw in text.splitlines():
            if raw.strip() in ("---", "..."):
                continue
            content = _strip_comment(raw).rstrip()
            if not content.strip():
                self.lines.append((-1, "", raw))
                continue
            indent = len(content) - len(content.lstrip(" "))
            self.lines.append((indent, content.strip(), raw))
        self.i = 0

    def _skip_blank(self) -> None:
        while self.i < len(self.lines) and self.lines[self.i][0] < 0:
            self.i += 1

    def _peek(self) -> tuple[int, str, str] | None:
        self._skip_blank()
        return self.lines[self.i] if self.i < len(self.lines) else None

    def parse(self) -> Any:
        first = self._peek()
        if first is None:
            return None
        if first[0] == 0 and not _is_seq(first[1]) and not _KEY.match(first[1]):
            return _value(first[1])
        return self._block(first[0])

    def _block(self, indent: int) -> Any:
        line = self._peek()
        if line is None:
            return None
        return self._seq(indent) if _is_seq(line[1]) else self._map(indent)

    def _block_scalar(self, style: str, parent_indent: int) -> str:
        parts: list[str] = []
        self.i += 1
        while self.i < len(self.lines):
            indent, _content, raw = self.lines[self.i]
            if indent >= 0 and indent <= parent_indent:
                break
            parts.append(raw.strip())
            self.i += 1
        while parts and parts[-1] == "":
            parts.pop()
        text = "\n".join(parts) if style.startswith("|") else " ".join(p for p in parts if p)
        return text if style.endswith("-") else text + "\n"

    def _flow_block(self) -> Any:
        """A [list] or {map} that starts on its own line and may span several lines."""
        text, depth = "", 0
        while self.i < len(self.lines):
            _indent, content, _raw = self.lines[self.i]
            self.i += 1
            if _indent < 0:
                continue
            text += " " + content
            depth += sum(content.count(c) for c in "[{") - sum(content.count(c) for c in "]}")
            if depth <= 0:
                break
        return _flow(text.strip())

    def _map(self, indent: int) -> dict[str, Any]:
        out: dict[str, Any] = {}
        while True:
            line = self._peek()
            if line is None or line[0] != indent or _is_seq(line[1]):
                return out
            m = _KEY.match(line[1])
            if not m:
                raise YamlError(f"expected 'key: value', got {line[1]!r}")
            key = str(_scalar(m.group("key")))
            rest = (m.group("rest") or "").strip()
            if rest in ("|", "|-", ">", ">-"):
                out[key] = self._block_scalar(rest, indent)
                continue
            self.i += 1
            if rest:
                out[key] = _value(rest)
                continue
            nxt = self._peek()
            if nxt is not None and nxt[0] > indent and nxt[1].startswith(("[", "{")):
                out[key] = self._flow_block()
            elif nxt is not None and (nxt[0] > indent or (nxt[0] == indent and _is_seq(nxt[1]))):
                out[key] = self._block(nxt[0])
            else:
                out[key] = None

    def _seq(self, indent: int) -> list[Any]:
        out: list[Any] = []
        while True:
            line = self._peek()
            if line is None or line[0] != indent or not _is_seq(line[1]):
                return out
            content = line[1][1:].lstrip()
            if not content:
                self.i += 1
                nxt = self._peek()
                out.append(self._block(nxt[0]) if nxt and nxt[0] > indent else None)
            elif _KEY.match(content) and not content.startswith(("[", "{", '"', "'")):
                child = indent + (len(line[1]) - len(content))
                self.lines[self.i] = (child, content, line[2])
                out.append(self._map(child))
            else:
                self.i += 1
                out.append(_value(content))


def _is_seq(content: str) -> bool:
    return content == "-" or content.startswith("- ")


# ----------------------------------------------------------------------------- helpers


def split_front_matter(text: str) -> tuple[dict[str, Any] | None, str]:
    """Return (front matter dict or None, body)."""
    if not text.startswith("---"):
        return None, text
    lines = text.splitlines(keepends=True)
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            data = parse_yaml("".join(lines[1:idx]))
            return (data if isinstance(data, dict) else {}), "".join(lines[idx + 1 :])
    return None, text


def load_entities(root: Path) -> dict[str, dict[str, Any]]:
    """Entities from ontology/entities/*.yaml, keyed by file stem. Files starting with _ skipped."""
    out: dict[str, dict[str, Any]] = {}
    folder = root / "ontology" / "entities"
    if not folder.is_dir():
        return out
    for f in sorted(folder.glob("*.y*ml")):
        if f.name.startswith("_"):
            continue
        data = parse_yaml(f.read_text(encoding="utf-8"))
        out[f.stem] = data if isinstance(data, dict) else {}
    return out


def load_yaml_file(path: Path) -> Any:
    if not path.exists():
        return None
    return parse_yaml(path.read_text(encoding="utf-8"))


def find_repo_root(start: Path | None = None) -> Path:
    here = (start or Path.cwd()).resolve()
    for d in (here, *here.parents):
        if (d / "ontology").is_dir() or (d / ".repo-setup.json").exists() or (d / ".git").exists():
            return d
    return here
