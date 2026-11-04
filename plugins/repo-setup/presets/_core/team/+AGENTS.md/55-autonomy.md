## Autonomy tiers

Changes are classified low / medium / high by `governance/autonomy.yaml`.

- Check the tier before you start: `python3 tools/autonomy.py --base origin/main`. High-tier edits
  need a human, and Claude Code asks before each one.
- Do not edit `.github/workflows/` or `governance/`: humans own them.
- Never delete or weaken a test to get green.
