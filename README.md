# a gothic-minimal Hyprland desktop

[![shell](https://img.shields.io/badge/shell-fish-a31621?style=flat-square&labelColor=0a0a0b)](#)
[![wm](https://img.shields.io/badge/wm-Hyprland-a31621?style=flat-square&labelColor=0a0a0b)](#)
[![platform](https://img.shields.io/badge/platform-Arch%20%7C%20CachyOS-a31621?style=flat-square&labelColor=0a0a0b&logo=archlinux&logoColor=d6d1c9)](#)
[![terminal](https://img.shields.io/badge/terminal-foot-a31621?style=flat-square&labelColor=0a0a0b)](#)
[![rice](https://img.shields.io/badge/rice-gothic%20minimal-a31621?style=flat-square&labelColor=0a0a0b)](#)
[![prompt](https://img.shields.io/badge/prompt-starship-a31621?style=flat-square&labelColor=0a0a0b)](#)

[![lint](https://github.com/ugolnikov/gothic-dots/actions/workflows/lint.yml/badge.svg)](https://github.com/ugolnikov/gothic-dots/actions/workflows/lint.yml)
[![last commit](https://img.shields.io/github/last-commit/ugolnikov/gothic-dots?style=flat-square&labelColor=0a0a0b&color=a31621)](#)
[![commits](https://img.shields.io/github/commit-activity/t/ugolnikov/gothic-dots?style=flat-square&labelColor=0a0a0b&color=a31621)](#)
[![repo size](https://img.shields.io/github/repo-size/ugolnikov/gothic-dots?style=flat-square&labelColor=0a0a0b&color=a31621)](#)
[![issues](https://img.shields.io/github/issues/ugolnikov/gothic-dots?style=flat-square&labelColor=0a0a0b&color=a31621)](https://github.com/ugolnikov/gothic-dots/issues)

Personal dotfiles, tuned for performance and low input latency, on a lightweight
stack (foot, Waybar, rofi, mako).

## Screenshots

Add your own images to `docs/screenshots/` and reference them here — see
`docs/screenshots/README.md` for how the rice is captured.

## Layout

```text
.
├── .gitignore                 # Git exclusions
├── .shellcheckrc              # ShellCheck options (external sources)
├── .markdownlint.jsonc        # Markdown lint rules for the docs
├── .gitattributes             # LF normalisation, binary/generated rules
├── bin/
│   └── please                 # run a command from history through sudo
├── fish/                      # Fish shell
│   ├── config.fish
│   ├── secrets.fish.EXAMPLE
│   ├── fishfile               # Fisher plugins
│   ├── conf.d/
│   │   ├── env.fish
│   │   ├── aliases.fish
│   │   ├── interactive.fish   # fzf, zoxide
│   │   ├── colors.fish        # gothic syntax highlighting (overrides stock fish colors)
│   │   └── prompt.fish
│   ├── completions/
│   │   └── please.fish
│   └── functions/
│       ├── cleanup.fish        # aggressive disk cleanup (caches, logs, trash)
│       ├── fish_greeting.fish
│       ├── my.fish             # list the abbreviations
│       ├── update.fish         # sync package databases
│       └── upgrade.fish        # upgrade the system
├── bash/                      # Bash (fallback shell)
│   ├── .bashrc                # → ~/.bashrc
│   └── .profile               # → ~/.profile
├── scripts/
│   ├── link-plan.sh           # single definition of what is linked where
│   ├── doctor.sh              # desktop health check (packages, links, fonts)
│   ├── dotfiles-backup.sh     # auto-snapshot and push to origin
│   ├── gen-keybinds.sh        # regenerate the README keybind table
│   ├── check-binds.sh         # binds.conf ↔ keybinds.tsv/scripts drift check
│   ├── check-coverage.sh      # every tracked config is in the link plan
│   ├── check-packages.sh      # packages.txt/aur.packages.txt vs Arch repos + AUR
│   ├── scan-secrets.sh        # block commits/pushes that look like secrets
│   └── server/                # server-only helpers (Ubuntu: apt, fail2ban, postgres)
│       ├── clean-ubuntu.sh
│       └── syscheck.sh
├── .githooks/
│   ├── pre-commit             # secret scan + syntax check before a commit
│   └── pre-push               # advisory check-binds / check-coverage before a push
├── .github/
│   ├── workflows/lint.yml     # CI: syntax, linters, guards, bats tests
│   ├── dependabot.yml         # keeps the pinned Action SHAs current
│   ├── ISSUE_TEMPLATE/        # issue forms
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── CODEOWNERS
├── SECURITY.md                # no secrets in-tree; report privately
├── tests/
│   └── dotfiles.bats          # smoke/regression tests for the tooling
├── systemd/                   # auto-backup units (installed to /etc/systemd/system)
│   ├── dotfiles-backup.service
│   └── dotfiles-backup.timer
├── gitconfig                  # → ~/.gitconfig
├── .editorconfig              # → ~/.editorconfig
├── tmux.conf                  # → ~/.tmux.conf
├── config/                    # → ~/.config/<app>/ (symlinked by install.sh)
│   ├── hypr/                  #   Hyprland rice: gothic minimal + perf (see its README)
│   ├── waybar/                #   config.jsonc, style.css, colors.css
│   ├── rofi/                  #   config.rasi, colors.rasi, powermenu.rasi
│   ├── foot/                  #   foot.ini (default terminal)
│   ├── tofi/                  #   tofi config (lightweight launcher; AUR)
│   ├── fontconfig/            #   fonts.conf (system-wide gothic font)
│   ├── gtk-3.0/ gtk-4.0/      #   settings.ini (GTK font / theme)
│   ├── qt6ct/ qt5ct/          #   theme and font for Qt apps
│   ├── dircolors/             #   gothic LS_COLORS (blue-free ls)
│   ├── kitty/                 #   kitty.conf, colors.conf (optional)
│   ├── mako/                  #   config
│   ├── bat/                   #   gothic tmTheme + config
│   ├── swaync/                #   config.json, style.css (mako alternative)
│   ├── yazi/                  #   yazi.toml (TUI file manager)
│   ├── wallust/               #   palette from the wallpaper (config + templates)
│   ├── starship.toml          #   Starship prompt (fish)
│   ├── fastfetch/             #   config.jsonc, sigil.txt (logo), logo.txt, logo_2.txt
│   ├── btop/                  #   btop.conf
│   ├── browsh/                #   config.toml
│   ├── git/                   #   ignore (global gitignore)
│   ├── htop/                  #   htoprc
│   ├── lazygit/               #   config.yml
│   ├── micro/                 #   settings.json, bindings.json
│   └── nvim/                  #   init.vim → ../../.vimrc; gothic airline theme
├── claude/                    # → ~/.claude/
│   ├── settings.json
│   └── settings.local.json.EXAMPLE
├── etc/                       # system configs (install.sh --system)
│   ├── systemd/zram-generator.conf
│   ├── systemd/oomd.conf
│   ├── ananicy.d/00-gothic.rules
│   └── keyd/default.conf      # ru-latin shortcuts while a modifier is held
├── Makefile                   # make install / test / lint / fmt / doctor / backup
└── install.sh                 # Auto-install (packages + symlinks; --only, --dry-run, …)
```

## Keybinds

Hyprland, `SUPER` is the modifier. Source: `config/hypr/conf.d/binds.conf`.
The table below is generated from `config/hypr/keybinds.tsv` by
`scripts/gen-keybinds.sh` (CI fails if it is out of date).

<!-- keybinds:start -->
| Key | Action |
|-----|--------|
| `SUPER + Return` | terminal (foot) |
| `SUPER + D` / `SUPER + Space` | app launcher (tofi) |
| `SUPER + E` | file manager |
| `SUPER + B` | browser |
| `SUPER + Q` | close window |
| `SUPER + Shift + Q` | exit session |
| `SUPER + Shift + E` | power menu |
| `SUPER + V` | toggle floating |
| `SUPER + Shift + V` | clipboard history (rofi) |
| `SUPER + P` | pseudo tile |
| `SUPER + G` | toggle split |
| `SUPER + F` | fullscreen (maximize) |
| `SUPER + Shift + F` | true fullscreen |
| `SUPER + ,` | settings |
| `SUPER + Shift + C` | quick panel (DND, night light, caffeine, recording) |
| `SUPER + Shift + M` | session (save / restore window layout) |
| `SUPER + /` | keybind cheatsheet |
| `SUPER + W` | wallpaper picker |
| `SUPER + R` / `SUPER + Shift + R` | reload Hyprland / restart Waybar |
| `SUPER + N` | dismiss notifications |
| `SUPER + C` | color picker |
| `SUPER + M` | network connections (nm-connection-editor) |
| `SUPER + Shift + T` | toggle light / dark theme |
| `SUPER + X` | lock screen |
| `SUPER + H J K L` / arrows | move focus |
| `SUPER + Shift + H J K L` / arrows | move window |
| `SUPER + Ctrl + H J K L` | resize window |
| `SUPER + 1..0` | switch workspace |
| `SUPER + Shift + 1..0` | move window to workspace |
| `SUPER + Tab` | previous workspace |
| `SUPER + scroll` | next / previous workspace |
| `SUPER + grave` | scratchpad (special workspace) |
| `SUPER + Shift + grave` | move window to scratchpad |
| `SUPER + drag` (LMB / RMB) | move / resize window |
| `Print` / `SUPER + Print` / `SUPER + Shift + Print` | screenshot: full / region / window |
| `SUPER + Shift + S` | screenshot: region → annotate (swappy) |
| `Alt + Shift` | switch keyboard layout (us / ru) |
| `Caps Lock` | Escape |
| `XF86 Audio*` / `XF86 Brightness*` | volume / media / brightness |
<!-- keybinds:end -->

## Theme

The desktop ships a fixed **gothic** (dark) palette by default. One module,
`config/hypr/scripts/palette.sh`, owns the palette and keeps a **single**
persisted mode in `~/.config/hypr/palette-mode` — `dark`, `light` or `dynamic` —
writes the generated color files and reloads the apps that consume them.
`light` (the "ivory" variant) and `dynamic` (wallpaper-derived via
[wallust](https://codeberg.org/explosion-mental/wallust)) are mutually
exclusive, and `dark` clears all generated color.

```bash
~/.config/hypr/scripts/palette.sh status         # dark | light | dynamic
~/.config/hypr/scripts/palette.sh set light      # light "ivory" palette
~/.config/hypr/scripts/palette.sh set dynamic    # wallpaper-derived palette
~/.config/hypr/scripts/palette.sh set dark       # back to the fixed gothic palette
~/.config/hypr/scripts/palette.sh clear          # drop generated colour, back to dark
```

`SUPER + Shift + T` toggles dark ⇄ light. See
[`config/hypr/README.md`](config/hypr/README.md) for the full picture.

## Quick controls

`SUPER + Shift + C` opens a rofi panel with four session toggles. Active ones
also appear as a red `DND · NIGHT · CAFFEINE · REC` tag at the right of Waybar;
the tag is hidden while nothing is on, so the bar stays minimal. One module,
`config/hypr/scripts/controls.sh`, owns both the state and the actions:

```bash
~/.config/hypr/scripts/controls.sh status          # every toggle at once
~/.config/hypr/scripts/controls.sh dnd toggle      # mako / swaync do-not-disturb
~/.config/hypr/scripts/controls.sh night on 4000   # hyprsunset, 1000..10000K
~/.config/hypr/scripts/controls.sh caffeine on     # block idle and sleep
~/.config/hypr/scripts/controls.sh record start full audio
~/.config/hypr/scripts/controls.sh record stop     # saved to ~/Videos/Recordings
```

State lives in markers under `~/.config/hypr/` (`dnd`, `night-light`,
`caffeine`, `recording`); `conf.d/autostart.conf` runs `controls.sh restore`, so
DND, night light and caffeine survive a relogin. Recording never restarts by
itself. `controls.sh reset` turns everything off. The panel is only a view —
`config/hypr/scripts/quick.sh` reads states and hands the chosen row back to the
module.

## Sessions

`SUPER + Shift + M` opens the session menu: save the current window layout, or
put a saved one back. One module, `config/hypr/scripts/session.sh`, owns the
snapshots — JSON files in `~/.config/hypr/sessions/` (mode 600, gitignored).

```bash
~/.config/hypr/scripts/session.sh save work       # snapshot the layout
~/.config/hypr/scripts/session.sh list            # what is saved
~/.config/hypr/scripts/session.sh show work       # windows, workspaces, argv
~/.config/hypr/scripts/session.sh restore work    # put it back
~/.config/hypr/scripts/session.sh restore work --dry-run
~/.config/hypr/scripts/session.sh delete work
```

A snapshot records, per window: class, title, workspace (including named
special workspaces), tiled/floating, position and size, pinned and fullscreen,
plus the argv and working directory read from `/proc`. Restore never closes
anything: windows that are already open are matched by class and moved to their
workspace, missing applications are started with exactly the argv they had
(no `eval`, arguments keep their spaces and quotes) and are given
`SESSION_WAIT` seconds to appear. `save` also keeps a copy as `last`, so
`session.sh restore last` brings back the most recent layout after a crash or a
compositor restart. To make that automatic, add
`exec-once = ~/.config/hypr/scripts/session.sh restore last` to
`conf.d/autostart.conf` — it is deliberately off by default, since a login
should not launch apps on its own.

## Install

### Quick (auto-install)

```bash
git clone https://github.com/ugolnikov/gothic-dots.git ~/dotfiles
cd ~/dotfiles
./install.sh                 # Arch/CachyOS: packages (repo + AUR) and config symlinks
./install.sh --no-packages   # symlink configs only
./install.sh --timer         # also enable the systemd auto-backup
./install.sh --system        # also install system configs (zram/oomd/ananicy/irqbalance/keyd)
./install.sh --force         # overwrite existing targets without a backup
./install.sh --dry-run       # print the steps, change nothing
./install.sh --uninstall     # remove this repo's symlinks (inverse of install)
./install.sh --only hypr,waybar  # link only the named apps (implies --no-packages)
```

Existing configs are never destroyed. Anything that would be replaced is moved
to `~/.dotfiles-backup/<timestamp>/` first, keeping its relative path, and the
target becomes a symlink into this repo. Re-running is idempotent: this repo's
own symlinks are refreshed, not backed up. Use `--dry-run` to preview conflicts
and `--force` to skip the backup. `--uninstall` reverses the links safely
(only symlinks pointing into this repo are removed).

Run `scripts/doctor.sh` afterwards to check packages, symlinks, fonts and the
Hyprland config in one pass.

On a fresh machine, `scripts/first-run.sh` (or `make first-run`) walks the same
steps one at a time, with a confirmation before each:

```bash
./scripts/first-run.sh            # interactive: confirm each stage
./scripts/first-run.sh --yes      # accept every confirmation
./scripts/first-run.sh --dry-run  # print the commands; change nothing
```

It installs the packages, links the configs, and offers the optional system
configs, auto-backup timer and login shell. It never creates secrets — the
secret stage prints the tracked `*.EXAMPLE` copies you fill in by hand.

### Manual

```bash
cd ~/dotfiles

ln -sf $PWD/gitconfig ~/.gitconfig
ln -sf $PWD/tmux.conf ~/.tmux.conf
ln -sf $PWD/.editorconfig ~/.editorconfig

# ~/.config apps (Hyprland rice + the rest). The glob mirrors install.sh, so
# the list can never drift from config/ again.
mkdir -p ~/.config
for d in "$PWD"/config/*/; do
  ln -sfn "${d%/}" "$HOME/.config/$(basename "$d")"
done
# config/starship.toml is a file, not a directory
ln -sfn "$PWD/config/starship.toml" "$HOME/.config/starship.toml"

# Claude
mkdir -p ~/.claude && ln -sf $PWD/claude/settings.json ~/.claude/settings.json

# Fish
ln -sf $PWD/fish ~/.config/fish

# bin → ~/.local/bin (must be on PATH; install.sh adds please here)
mkdir -p ~/.local/bin
for b in "$PWD"/bin/*; do
  ln -sf "$b" "$HOME/.local/bin/$(basename "$b")"
done

# Bash (fallback)
ln -sf $PWD/bash/.bashrc ~/.bashrc
ln -sf $PWD/bash/.profile ~/.profile

# Secrets (never in the repository)
cp fish/secrets.fish.EXAMPLE ~/.secrets.fish
# then edit them with your own keys

# Machine-specific Claude overrides
cp claude/settings.local.json.EXAMPLE ~/.claude/settings.local.json
```

### Starship prompt

The prompt (fish) is **Starship**, themed gothic. It reads
`~/.config/starship.toml`, or `~/.cache/wallust/starship.toml` when the
wallpaper-derived palette is active (`palette.sh set dynamic`). Install:
`starship` (already in `config/hypr/packages.txt`).

## Tasks

A thin `Makefile` wraps the common jobs (`make` or `make help` lists them):

```bash
make install         # link configs (no packages)
make first-run       # walk a fresh clone through the one-time setup
make test            # bats test suite
make lint            # secrets, binds, coverage, keybind table
make fmt             # shfmt + fish_indent
make doctor          # desktop health check
make backup          # snapshot local edits to the snapshots branch
make check-packages  # validate package names against Arch repos + AUR
```

## Auto-backup

The repository is the source of truth; local edits reach GitHub on their own.
`scripts/dotfiles-backup.sh` snapshots the working tree and pushes it to a
dedicated `snapshots` branch — **not** `main` — so `main` stays reserved for
hand-written commits. It builds the commit with plumbing, so your working tree
and current branch are left untouched (only the index is used, then reset); on a
clean tree it just exits. It is driven by the systemd timer
`dotfiles-backup.timer` (right after boot and every 6 hours thereafter). Set
`DOTFILES_SNAPSHOT_BRANCH` to use another branch. Snapshots made before this
change already sit on `main`; they are left as-is (no history rewrite).

```bash
# run by hand
./scripts/dotfiles-backup.sh

# install and enable the timer (root required).
# ./install.sh --timer substitutes @DOTFILES@/@USER@/@HOME@ in the unit, so it
# works from any clone path and runs as the repo owner instead of root.
./install.sh --timer

# status and logs
systemctl list-timers dotfiles-backup.timer
journalctl -u dotfiles-backup.service
```

Secrets never reach the backup: they live outside the repository
(`~/.secrets.fish`, `~/.ssh`) and are listed in `.gitignore`.

## Hooks and checks

As defense in depth the repository ships a pre-commit hook and a secret scanner:

* `scripts/scan-secrets.sh` — flags files that look like they carry a
  credential. `dotfiles-backup.sh` runs it before every automatic push, and the
  hook runs it before every commit.
* `scripts/check-binds.sh` — fails when a bind uses an undefined `$variable`, a
  missing script, an unknown dispatcher, or a key that is not listed in
  `config/hypr/keybinds.tsv`. Runs in CI.
* `scripts/check-coverage.sh` — fails when a tracked config is not in the link
  plan (`scripts/link-plan.sh`), which it reads directly, so the guard cannot
  drift from what the installer links. Runs in CI.
* `scripts/check-palette-targets.sh` — fails when the palette module's target
  table drifts from the wallust destinations, `.gitignore` or `.gitattributes`,
  or when its light palette is bound to targets by position instead of by name.
  Runs in CI.
* `.githooks/pre-commit` — blocks the commit on a suspected secret or a bash
  syntax error; shellcheck and fish checks are advisory. `install.sh` enables it
  with `git config core.hooksPath .githooks`.
* `.githooks/pre-push` — advisory `check-binds` / `check-coverage` /
  `check-palette-targets` / secret scan before a push, so drift is caught
  locally instead of in CI.

CI (`.github/workflows/lint.yml`) runs the same gates plus `shfmt` and
`actionlint`, `fish -n` + `fish_indent`, JSON/JSONC/TOML/YAML parsing,
`markdownlint-cli2` (rules in `.markdownlint.jsonc`) and the `bats` tests in
`tests/`. The GitHub Actions are pinned to commit SHAs, kept current by
Dependabot (`.github/dependabot.yml`).

The security policy is in [`SECURITY.md`](SECURITY.md): keep secrets in
`~/.secrets.fish` / `~/.secrets.sh`, and report problems privately.

```bash
# scan everything by hand
./scripts/scan-secrets.sh --all

# refresh the README keybind table after editing config/hypr/keybinds.tsv
./scripts/gen-keybinds.sh
./scripts/gen-keybinds.sh --check   # what CI runs

# run the test suite (needs bats)
bats tests/
```

## Troubleshooting

* **Icons or glyphs show as boxes** — install a Nerd Font and rebuild the cache
  (`fc-cache -f`); the rice expects `JetBrainsMono Nerd Font`.
* **A config didn't apply after install** — re-run `./install.sh` (idempotent)
  and `scripts/doctor.sh` to list missing commands, links or fonts.
* **Hyprland started with errors** — check `hyprctl configerrors`. A missing
  `~/.config/hypr/conf.d/monitors.local.conf` is seeded by `install.sh` from the
  tracked `*.EXAMPLE`.
* **A keybind does nothing** — `./scripts/check-binds.sh` verifies the key is
  documented and the script it calls exists and is executable.
* **`fd` vs `fdfind`** — on Arch/CachyOS the binary is `fd`, on Debian/Ubuntu it
  is `fdfind`; both shells only add the alias when the wanted name is missing.
* **Secrets** — keep them in `~/.secrets.fish` / `~/.secrets.sh`, never in the
  repo; `./scripts/scan-secrets.sh --all` scans the tracked files.

## please

A utility to run commands from history through `sudo`. Works in fish and bash.

```text
please             # the last command, with sudo
please <TAB>       # pick a command from history (completion)
please apt update  # sudo apt update without digging through history
```

It detects the parent shell (fish/bash) automatically and reads its history.
