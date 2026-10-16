# Contributing

This repo is a gothic-minimal Hyprland desktop: the configs, the scripts that switch its look, and the guards that keep them honest. The domain language lives in [GLOSSARY.md](./GLOSSARY.md); how the code is written lives in [CODING_STANDARDS.md](./CODING_STANDARDS.md).

## Requirements

- **Arch / CachyOS** for the package lists (`packages.txt`, `aur.packages.txt`).
- `git`, and for the checks: `bats`, `shellcheck`. `make tools` installs the same pinned `shfmt` and `markdownlint-cli2` CI runs, so you can pass those gates before pushing.

## Getting started

```bash
git clone <your-fork> ~/dotfiles && cd ~/dotfiles
./install.sh --no-packages     # symlink the configs, no package changes
make test                      # the bats suite
make lint                      # the fast local guards
```

`./install.sh --dry-run` prints what it would link without touching anything. `./install.sh --uninstall` removes only this repo's symlinks.

## Making a change

1. Branch off `main`.
2. Make the change, with a test where the behaviour is observable (see [CODING_STANDARDS.md](./CODING_STANDARDS.md)).
3. Keep the gates green: `make test` and `make lint`.
4. Open a PR. Run `make fmt` before you push.

## The checks

`make lint` runs the guards CI also runs:

| Guard | Enforces |
| ----- | -------- |
| `scan-secrets.sh` | no secrets in tracked files |
| `check-binds.sh` | binds match their docs, scripts exist, dispatchers are known |
| `check-coverage.sh` | every tracked config is in the link plan (`scripts/link-plan.sh`) |
| `check-palette-targets.sh` | the palette target table matches `wallust.toml` |
| `gen-keybinds.sh --check` | the README keybind table is in sync |

`make test` runs the bats suite; `make doctor` health-checks a live desktop.

## Secrets

Never commit secrets. They live outside the repo and are covered by `.gitignore`; the tracked `*.EXAMPLE` files show the shape. `scan-secrets.sh` is a backstop, not a licence to commit them.

## Decisions

Hard-to-reverse, surprising decisions are recorded as ADRs in `docs/adr/`. Use the terms from [GLOSSARY.md](./GLOSSARY.md) in issues, commits and ADRs.
