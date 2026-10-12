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

Personal dotfiles, tuned for performance and low input latency, on a lightweight
stack (foot, Waybar, rofi, mako).

## Screenshots

Add your own images to `docs/screenshots/` and reference them here — see
`docs/screenshots/README.md` for how the rice is captured.

## Layout

```
.
├── .gitignore                 # Git exclusions
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
│       └── fish_greeting.fish
├── bash/                      # Bash (fallback shell)
│   ├── .bashrc                # → ~/.bashrc
│   └── .profile               # → ~/.profile
├── scripts/
│   ├── doctor.sh              # desktop health check (packages, links, fonts)
│   ├── dotfiles-backup.sh     # auto-snapshot and push to origin
│   ├── gen-keybinds.sh        # regenerate the README keybind table
│   ├── scan-secrets.sh        # block commits/pushes that look like secrets
│   └── server/                # server-only helpers (Ubuntu: apt, fail2ban, postgres)
│       ├── clean-ubuntu.sh
│       └── syscheck.sh
├── .githooks/
│   └── pre-commit             # secret scan + syntax check before a commit
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
│   └── nvim/init.vim          #   → ../../.vimrc
├── claude/                    # → ~/.claude/
│   ├── settings.json
│   └── settings.local.json.EXAMPLE
├── etc/                       # system configs (install.sh --system)
│   ├── systemd/zram-generator.conf
│   ├── systemd/oomd.conf
│   └── ananicy.d/00-gothic.rules
└── install.sh                 # Auto-install (packages + symlinks)
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
| `SUPER + W` | wallpaper picker |
| `SUPER + R` / `SUPER + Shift + R` | reload Hyprland / restart Waybar |
| `SUPER + N` | dismiss notifications |
| `SUPER + C` | color picker |
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
| `SUPER + Alt + Shift` | switch keyboard layout (us / ru) |
| `Caps Lock` | Escape |
| `XF86 Audio*` / `XF86 Brightness*` | volume / media / brightness |
<!-- keybinds:end -->

## Install

### Quick (auto-install)

```bash
git clone https://github.com/ugolnikov/gothic-dots.git ~/dotfiles
cd ~/dotfiles
./install.sh                 # Arch/CachyOS: packages (repo + AUR) and config symlinks
./install.sh --no-packages   # symlink configs only
./install.sh --timer         # also enable the systemd auto-backup
./install.sh --system        # also install system configs (zram/oomd/ananicy/irqbalance)
./install.sh --force         # overwrite existing targets without a backup
./install.sh --dry-run       # print the steps, change nothing
./install.sh --uninstall     # remove this repo's symlinks (inverse of install)
```

Existing configs are never destroyed. Anything that would be replaced is moved
to `~/.dotfiles-backup/<timestamp>/` first, keeping its relative path, and the
target becomes a symlink into this repo. Re-running is idempotent: this repo's
own symlinks are refreshed, not backed up. Use `--dry-run` to preview conflicts
and `--force` to skip the backup. `--uninstall` reverses the links safely
(only symlinks pointing into this repo are removed).

Run `scripts/doctor.sh` afterwards to check packages, symlinks, fonts and the
Hyprland config in one pass.

### Manual

```bash
cd ~/dotfiles

ln -sf $PWD/gitconfig ~/.gitconfig
ln -sf $PWD/tmux.conf ~/.tmux.conf
ln -sf $PWD/.editorconfig ~/.editorconfig

# ~/.config apps (Hyprland rice + the rest)
mkdir -p ~/.config
for d in hypr waybar rofi foot fontconfig gtk-3.0 gtk-4.0 qt6ct qt5ct kitty mako swaync wallust fastfetch btop browsh git htop lazygit micro nvim; do
  ln -sfn "$PWD/config/$d" "$HOME/.config/$d"
done

# Claude
mkdir -p ~/.claude && ln -sf $PWD/claude/settings.json ~/.claude/settings.json

# Fish
ln -sf $PWD/fish ~/.config/fish

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
wallpaper-derived palette is enabled. Install: `starship` (already in
`config/hypr/packages.txt`).

## Auto-backup

The repository is the source of truth; local edits reach GitHub on their own.
`scripts/dotfiles-backup.sh` runs `git add -A`, commits a snapshot and pushes to
`origin`; on a clean tree it just exits. It is driven by the systemd timer
`dotfiles-backup.timer` (right after boot and every 6 hours thereafter).

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
* `.githooks/pre-commit` — blocks the commit on a suspected secret or a bash
  syntax error; shellcheck and fish checks are advisory. `install.sh` enables it
  with `git config core.hooksPath .githooks`.

```bash
# scan everything by hand
./scripts/scan-secrets.sh --all

# refresh the README keybind table after editing config/hypr/keybinds.tsv
./scripts/gen-keybinds.sh
./scripts/gen-keybinds.sh --check   # what CI runs
```

## please

A utility to run commands from history through `sudo`. Works in fish and bash.

```
please             # the last command, with sudo
please <TAB>       # pick a command from history (completion)
please apt update  # sudo apt update without digging through history
```

It detects the parent shell (fish/bash) automatically and reads its history.
