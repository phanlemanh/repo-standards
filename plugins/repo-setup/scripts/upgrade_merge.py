"""Merge a file the repository edited with the plugin's new template, three ways.

`git merge-file --diff3` does the merge. Where the two sides meet, the file gets conflict markers
labelled so the reader knows which side is which; `tools/upgrade_markers.py` keeps `make check`
red until they are gone. An empty base is a two-way merge: everything that differs is marked.

package.json is merged key by key where the line merge meets: npm writes the keys it adds right
after the last block, so a line the template adds at the end of `scripts` always touches them.

A file whose template ends with a section the plugin writes (AGENTS.md) is merged in two parts
where the line merge meets: a repository adds its own text at the end too, and there the order is
known, since the section's place is last.

Only the Python standard library and git are used (Python 3.11+).
"""

from __future__ import annotations

import json
import re
import subprocess
import tempfile
from pathlib import Path

OURS_LABEL = "this repository"
NO_BASE_LABEL = "repo-setup: no matching base"
MERGE_TIMEOUT = 60  # seconds
KEY_MERGED_NAMES = frozenset({"package.json"})


class MergeUnavailable(Exception):
    """git is missing, or refused the merge (a binary file, for instance)."""


def release_label(version: str) -> str:
    return f"repo-setup {version}"


def three_way(
    current: bytes, base: bytes, new: bytes, base_label: str, new_label: str
) -> tuple[bytes, bool]:
    """(merged content, True when no conflict markers were needed)."""
    if any(b"\x00" in part for part in (current, base, new)):
        raise MergeUnavailable("binary file: git merge-file does not merge it")
    with tempfile.TemporaryDirectory() as tmp:
        paths = []
        for name, data in (("current", current), ("base", base), ("new", new)):
            path = Path(tmp) / name
            path.write_bytes(data)
            paths.append(str(path))
        cmd = ["git", "merge-file", "-p", "--diff3",
               "-L", OURS_LABEL, "-L", base_label, "-L", new_label, *paths]
        try:
            proc = subprocess.run(cmd, capture_output=True, timeout=MERGE_TIMEOUT)
        except (OSError, subprocess.SubprocessError) as exc:
            raise MergeUnavailable(f"cannot run git merge-file: {exc}") from exc
    # git merge-file exits with the number of conflicts, or a negative value on error
    # (seen as 128 and above by a shell).
    if proc.returncode < 0 or proc.returncode >= 128:
        detail = proc.stderr.decode("utf-8", "replace").strip()
        raise MergeUnavailable(f"git merge-file failed: {detail or proc.returncode}")
    return proc.stdout, proc.returncode == 0


class _KeyConflict(Exception):
    """Both sides changed the same key, differently."""


_MISSING = object()  # a key one side does not have
_INDENT = re.compile(r"\A\{\n([ \t]+)\"")


def _merge_value(ours: object, base: object, theirs: object) -> object:
    if theirs == base:
        return ours
    if ours == base or ours == theirs:
        return theirs
    if all(isinstance(v, dict) for v in (ours, base, theirs)):
        return _merge_object(ours, base, theirs)  # type: ignore[arg-type]
    raise _KeyConflict


def _merge_object(ours: dict, base: dict, theirs: dict) -> dict:
    """This repository's keys in its order; a key only the template adds goes after the key that
    comes before it in the template (first when none does)."""
    items = [
        (key, value)
        for key, value in (
            (k, _merge_value(v, base.get(k, _MISSING), theirs.get(k, _MISSING)))
            for k, v in ours.items()
        )
        if value is not _MISSING
    ]
    anchor = None
    for key, value in theirs.items():
        if key not in ours:
            merged = _merge_value(_MISSING, base.get(key, _MISSING), value)
            if merged is _MISSING:
                continue
            keys = [k for k, _ in items]
            items.insert(0 if anchor is None else keys.index(anchor) + 1, (key, merged))
        if any(k == key for k, _ in items):
            anchor = key
    return dict(items)


def _as_npm_writes(data: dict, indent: str, newline: bool) -> str:
    """What npm (JSON.stringify with the file's own indent) writes for `data`."""
    return json.dumps(data, indent=indent, ensure_ascii=False) + ("\n" if newline else "")


def merge_by_key(current: bytes, base: bytes, new: bytes) -> bytes | None:
    """A three-way merge of a JSON object key by key, or None when it cannot be one.

    None when a side is not a JSON object, when both sides changed one key differently, or when
    this repository's file is not written the way npm writes package.json: the merge writes the
    whole file again, and a file someone formatted by hand must not be reformatted."""
    crlf = _is_crlf(current)
    try:
        text = current.decode("utf-8").replace("\r\n", "\n")
        ours, old, theirs = (json.loads(t) for t in (text, base.decode("utf-8"), new.decode("utf-8")))
    except (UnicodeDecodeError, ValueError):
        return None
    indent = _INDENT.match(text)
    if not all(isinstance(v, dict) for v in (ours, old, theirs)) or indent is None:
        return None
    newline = text.endswith("\n")
    if _as_npm_writes(ours, indent.group(1), newline) != text:
        return None
    try:
        merged = _merge_object(ours, old, theirs)
    except _KeyConflict:
        return None
    out = _as_npm_writes(merged, indent.group(1), newline).encode("utf-8")
    return _crlf(out) if crlf else out


def _is_crlf(data: bytes) -> bool:
    return b"\r\n" in data and data.count(b"\n") == data.count(b"\r\n")


def _crlf(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")


def _split_tail(data: bytes, heading: bytes, newline: bytes) -> tuple[bytes, bytes]:
    """(what comes before the line `heading`, from that line to the end of the file). Without
    such a line the second part is empty. The blank lines between the two belong to neither, and
    spaces after the heading do not hide it."""
    lines = data.splitlines(keepends=True)
    for at, line in enumerate(lines):
        if line.rstrip() == heading:
            before = b"".join(lines[:at]).rstrip(b"\r\n")
            return (before + newline if before else b""), b"".join(lines[at:])
    return data, b""


def _appended(ours: bytes, old: bytes) -> tuple[bytes, bytes] | None:
    """(the repository's text up to the template's last line, the lines it added after that line),
    or None when nothing comes after it, or the template's last line is not there as it was."""
    old_lines, our_lines = old.splitlines(keepends=True), ours.splitlines(keepends=True)
    if not old_lines:
        return None
    last = old_lines[-1].rstrip(b"\r\n")
    for at in range(len(our_lines) - 1, -1, -1):
        if our_lines[at].rstrip(b"\r\n") == last:
            extra = b"".join(our_lines[at + 1 :])
            return (b"".join(our_lines[: at + 1]), extra) if extra.strip() else None
    return None


def merge_with_tail(
    current: bytes, base: bytes, new: bytes, heading: bytes, base_label: str, new_label: str
) -> tuple[bytes, bool] | None:
    """The three-way merge in two parts, for a template that ends with a section the plugin
    writes, from the line `heading` to the end: what comes before the section, then the section.

    The section's place is last, so text the repository added at the end of its file stays before
    it and the two no longer meet. Lines the repository added after the template's last line are
    put back after the merged text, so a change of that last line does not meet them either; the
    rest is merged three ways as before, and marked where the two sides meet. A template without
    the section (an adopted repository) is one part. Returns (content, True when no conflict
    markers were needed), or None when the section itself meets what the repository did to it,
    or git cannot merge."""
    newline = b"\r\n" if _is_crlf(current) else b"\n"
    (ours, our_tail), (old, old_tail), (theirs, their_tail) = (
        _split_tail(data, heading, newline) for data in (current, base, new)
    )
    try:
        tail, tail_clean = three_way(our_tail, old_tail, their_tail, base_label, new_label)
        if not tail_clean:
            return None
        # git merge-file marks two edits that touch: the template changing its last line and the
        # repository adding lines right after it. Those lines are set aside and put back after.
        parts = _appended(ours, old)
        core, extra = parts if parts else (ours, b"")
        body, body_clean = three_way(core, old, theirs, base_label, new_label)
        if extra:
            body = body.rstrip(b"\r\n") + newline + extra
    except MergeUnavailable:
        return None
    if not tail:
        return body, body_clean
    return body.rstrip(b"\r\n") + newline * 2 + tail, body_clean


def merges_by_key(path: str) -> bool:
    """package.json: npm writes it again on every install, and puts the keys it adds right after
    the last block, where the template adds its own lines too."""
    return Path(path).name in KEY_MERGED_NAMES


def reconcile(
    current: bytes,
    new: bytes,
    base: bytes | None,
    base_version: str | None,
    new_version: str,
    by_key: bool = False,
    tail_heading: bytes | None = None,
) -> tuple[str, bytes | None, str]:
    """What to do with a file the repository edited in place, now that the template is `new`.

    `base` is what the plugin wrote last time (None when no release gives it: the merge is then
    two-way). Returns (group, content to write or None, reason): `edited` (nothing to do),
    `merged`, `marked` (written with conflict markers) or `base_unread` (git could not merge).
    A repository whose file ends its lines with CRLF keeps them. With `by_key`, a JSON object
    whose line merge meets is merged key by key when that keeps both sides (`merge_by_key`).
    With `tail_heading`, a file whose line merge meets is merged in two parts, the section that
    starts at that line apart from what comes before it (`merge_with_tail`)."""
    if base is not None and base == new:
        return "edited", None, ""
    base_bytes = base if base is not None else b""
    base_label = release_label(base_version) if base is not None and base_version else NO_BASE_LABEL
    new_label = release_label(new_version)
    template = new
    if _is_crlf(current):
        base_bytes, new = _crlf(base_bytes), _crlf(new)
    try:
        merged, clean = three_way(current, base_bytes, new, base_label, new_label)
    except MergeUnavailable as exc:
        return "base_unread", None, str(exc)
    if not clean and tail_heading and base is not None:
        parted = merge_with_tail(current, base_bytes, new, tail_heading, base_label, new_label)
        if parted is not None:
            merged, clean = parted
    if not clean and by_key and base is not None:
        keyed = merge_by_key(current, base, template)
        if keyed is not None:
            merged, clean = keyed, True
    if not clean:
        return "marked", merged, ""
    if merged == current:
        return "edited", None, ""
    return "merged", merged, ""
