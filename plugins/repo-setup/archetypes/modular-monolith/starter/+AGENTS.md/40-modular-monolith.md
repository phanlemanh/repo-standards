## Architecture: modular monolith

- Business code lives in modules under `src/**/modules/<name>/` (one per bounded context).
  `architecture/modules.yaml` lists them, which entities each owns, and who may depend on whom.
- A module uses another module **only** through its public API (`modules/<name>/index.ts`, or
  the `<pkg>.modules.<name>` package), and only if `depends_on` allows it. `make check` fails
  otherwise (`tools/boundaries.py`).
- Put a new rule in the module that owns the entity. Need a new dependency between modules?
  That is a design change: update `modules.yaml`, explain it in the PR, add a decision page.
- Prefer passing ids and calling the other module's public functions over sharing data
  structures; never reach into another module's tables or internal files.
