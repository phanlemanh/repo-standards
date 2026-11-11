# sample-market

An existing Claude Code plugin marketplace with two plugins. It stands in for a real repository
in the repo-setup tests: it has its own tests, CI, changelog and bump script, and lacks the
shared basics (editor config, pinned runtime, task runner, agent guide).

## Install

```
/plugin marketplace add acme/sample-market
/plugin install alpha@sample-market
```

## Develop

```bash
bash tests/run.sh
```
