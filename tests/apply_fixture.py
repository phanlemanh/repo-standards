#!/usr/bin/env python3
"""Copy a sample domain (tests/fixtures/<name>) into a generated repo, the way an agent would:
entities + relations + wiki page, glossary rows appended, wiki index linked."""
import shutil
import sys
from pathlib import Path

fixture = Path(__file__).parent / "fixtures" / sys.argv[1]
repo = Path(sys.argv[2])

for src in fixture.rglob("*"):
    if src.is_file() and src.name != "glossary-rows.md":
        dest = repo / src.relative_to(fixture)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dest)

glossary = repo / "ontology" / "glossary.md"
lines = glossary.read_text().splitlines()
example = next(i for i, ln in enumerate(lines) if ln.startswith("| _Example:_"))
rows = (fixture / "glossary-rows.md").read_text().splitlines()
glossary.write_text("\n".join(lines[: example + 1] + rows + lines[example + 1 :]) + "\n")

index = repo / "wiki" / "index.md"
text = index.read_text().replace(
    "<!-- - [Customer](entities/customer.md) — who buys; VIP rules -->",
    "- [Customer](entities/customer.md) — who buys; VIP rules",
)
index.write_text(text)
print(f"fixture {sys.argv[1]} applied to {repo}")
