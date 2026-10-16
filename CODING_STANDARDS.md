# Coding standards

The rules the guards and CI assume. Where tooling enforces a rule, it says so; otherwise it is on you.

## Shell

- Every script starts with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Scripts are standalone executables with a small subcommand CLI (see `config/hypr/scripts/palette.sh`). Unknown input prints usage to stderr and exits non-zero.
- Guard scripts live in `scripts/`, are named `check-<thing>.sh`, and exit non-zero on drift.
- Prefer returning a result over mutating global state; keep a command's read and write paths distinct.
- A command that may be absent is guarded with `command -v`. A failing reload of a colour consumer is ignored (`|| true`), never fatal.

## Comments and language

- `scripts/` and `tests/`: English.
- `config/hypr/scripts/`: Russian, matching the surrounding files.

## Naming

- Executables: `kebab-case.sh`. Functions and variables: `snake_case`; exported values `UPPER_CASE`.

## Formatting

- 4-space indent; `shfmt -i 4 -ci` (CI checks it). Fish: `fish_indent`.
- Markdown: `markdownlint` (CI). Tag every fenced block with a language.

## Tests

- `bats`, one file per area, under `tests/`.
- Test **external behaviour**, not internals: run the real script against a throwaway `XDG_CONFIG_HOME`/`XDG_CACHE_HOME` and stub external binaries on `PATH`. Never touch the real `~/.config`.
- A change that alters observable behaviour comes with a test that fails before it.

## Guards and docs

- A new home dotfile or config dir must be linked by `install.sh`, or `check-coverage.sh` fails; allow-list only files deliberately not linked.
- A bind needs a `keybinds.tsv` row; the README table is generated, never hand-edited.
- Use the vocabulary in [GLOSSARY.md](./GLOSSARY.md); record hard-to-reverse decisions as ADRs in `docs/adr/`.
