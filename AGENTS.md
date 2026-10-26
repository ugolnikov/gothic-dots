# Agent guide

## Agent skills

### Issue tracker

Issues and specs for this repo live as GitHub issues (via the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, each label string equal to its role name. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Default workflow

Ponytail (level: full) on every coding task: the smallest complete change.

Route by size:

- Trivial (typo, one-liner, config value, small bugfix in one file): just make the change, following `CODING_STANDARDS.md`.
- Non-trivial (new feature, 2+ files, architectural decision, migration, refactor): run the pipeline in order — `grill-with-docs` → `to-spec` → `to-tickets` → `implement-spec`. Do not implement straight from the request, and do not skip a stage.
- The user may waive the pipeline explicitly ("просто сделай"); then say so in one line.

Tests, lint (`make lint`) and `bats tests/` must actually run before a PR is called done. Then commit, push, open the PR, wait for CI, merge.

