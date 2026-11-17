#!/usr/bin/env python3
"""Copy a sample domain (tests/fixtures/<name>) into a generated repo, the way an agent would:
entities + relations + wiki page, glossary terms added with `tools/ledgers.py add-term`. The wiki
index lists the page by itself (a hand-kept index in an older repository is linked by hand)."""
import re
import shutil
import subprocess
import sys
from pathlib import Path

fixture = Path(__file__).parent / "fixtures" / sys.argv[1]
repo = Path(sys.argv[2])

for src in fixture.rglob("*"):
    if src.is_file() and src.name != "glossary-rows.md":
        dest = repo / src.relative_to(fixture)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dest)

for row in (fixture / "glossary-rows.md").read_text().splitlines():
    cells = [c.strip() for c in re.split(r"(?<!\\)\|", row.strip())[1:-1]]
    term, definition, confused, display = cells
    command = ["python3", "tools/ledgers.py", "add-term", term.strip("`"), "--definition", definition, "--display", display]
    if confused:
        command += ["--not-confused-with", confused]
    subprocess.run(command, cwd=repo, check=True, capture_output=True)

index = repo / "wiki" / "index.md"
if index.is_file() and not index.read_text().startswith("<!-- Drawn by"):
    index.write_text(index.read_text().replace(
        "<!-- - [Customer](entities/customer.md) — who buys; VIP rules -->",
        "- [Customer](entities/customer.md) — who buys; VIP rules",
    ))
print(f"fixture {sys.argv[1]} applied to {repo}")
