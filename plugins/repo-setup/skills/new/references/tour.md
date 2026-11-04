# Tour file

Write `docs/START-HERE.md` in the target repo, in `docs_language`, from what was actually built.
Keep the file name in English. Sections:

1. **Where things stand**: one or two sentences, including that a scaffold is not a finished
   product. Say what the sample code does.
2. **Three everyday commands**: `make dev`, `make format`, `make check`.
3. **What is in the repo**: a table of path, what it is, what you need to do. Group paths and list
   only what exists.
4. **What happens automatically**: CI on push, and `make check` in that CI. Nothing runs by itself inside Claude Code.
5. **What to know about safety**:
   - What the `doctor` score measures (files and checks are in place) and what it does not (whether
     the code is right).
   - `.claude/settings.json` helps avoid mistakes but is not an absolute barrier.
   - What this level does not include, for example pre-commit and secret scanning at `starter`.
6. **Not done yet**: features, GitHub repo, deployment, and every `manual_steps` entry.
7. **Next steps**: a first thing to ask Claude, and how to ask about a file you do not understand.

For a professional, add **Decisions**: one line per layer, pointing to `setup-blueprint.yaml`.
