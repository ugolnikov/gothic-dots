#!/usr/bin/env bash
# first-run.sh — walk a fresh clone through the one-time setup by hand.
#
#   scripts/first-run.sh            run the stages, confirming each one
#   scripts/first-run.sh --yes      accept every confirmation
#   scripts/first-run.sh --dry-run  print the planned commands; change nothing
#   scripts/first-run.sh -h         show this help
#
# It only drives the steps a human must do or confirm: install the packages,
# link the configs, and optionally add the system configs, the auto-backup timer
# and a login shell. Secrets are never created — the secret stage prints the
# *.EXAMPLE copies you make by hand with your own keys. Every command runs
# behind a confirmation, and the package, system and timer stages announce the
# sudo they run.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Overridable so tests can point at fixtures instead of the live machine.
SHELLS_FILE="${SHELLS_FILE:-/etc/shells}"
OS_RELEASE="${OS_RELEASE:-/etc/os-release}"
ARCH_RELEASE="${ARCH_RELEASE:-/etc/arch-release}"
# The package tool the wizard looks for. Tests set it empty to simulate a
# machine without pacman (on Arch it is always present, so PATH can't hide it).
PACMAN_BIN="${PACMAN_BIN-$(command -v pacman 2>/dev/null || true)}"

DRY=0
YES=0

usage() {
    cat <<'EOF'
usage: first-run.sh [--yes] [--dry-run]

  --yes       accept every confirmation (non-interactive)
  --dry-run   print the commands that would run; change nothing
  -h, --help  show this help
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --yes | -y) YES=1 ;;
        --dry-run) DRY=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "first-run.sh: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

# ── Wizard helpers ───────────────────────────────────────────────────────────
# Stage-by-stage progress, a confirmation before each step, and a closing
# summary of what was skipped. Output is plain when piped (tests, logs) and
# styled on a terminal.

TOTAL_STAGES=8
STAGE=0
SKIPPED=()

if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    BOLD=$(tput bold)
    DIM=$(tput dim)
    RESET=$(tput sgr0)
    BLUE=$(tput setaf 4)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
else
    BOLD=""
    DIM=""
    RESET=""
    BLUE=""
    GREEN=""
    YELLOW=""
fi

# clear_screen wipes the terminal so only the current stage is on screen. A
# no-op when output is not a terminal, so piped logs stay readable.
clear_screen() {
    [ -t 1 ] || return 0
    command -v tput >/dev/null 2>&1 && tput clear 2>/dev/null && return 0
    printf '\033[2J\033[3J\033[H'
}

# stage "Name" clears, then announces a stage and shows progress.
stage() {
    clear_screen
    STAGE=$((STAGE + 1))
    printf '\n%s%s▸ Stage %s/%s · %s%s\n' \
        "$BOLD" "$BLUE" "$STAGE" "$TOTAL_STAGES" "$1" "$RESET"
}

say() { printf '  %s\n' "$1"; }
step() { printf '  %s•%s %s\n' "$BLUE" "$RESET" "$1"; }
note() { printf '  %s%s%s\n' "$DIM" "$1" "$RESET"; }
warn() { printf '  %s⚠ %s%s\n' "$YELLOW" "$1" "$RESET"; }

# confirm "question" — a y/N gate before a step. --yes and --dry-run answer yes.
confirm() {
    if [ "$YES" = 1 ] || [ "$DRY" = 1 ]; then
        printf '  %s•%s %s (yes)\n' "$BLUE" "$RESET" "$1"
        return 0
    fi
    local reply=""
    printf '  %s? %s [y/N] ' "$YELLOW" "$1"
    read -r reply || true
    [[ "$reply" =~ ^[Yy] ]]
}

# pause "msg" — wait for the human; a no-op under --yes/--dry-run.
pause() {
    if [ "$YES" = 1 ] || [ "$DRY" = 1 ]; then
        return 0
    fi
    printf '  %s%s%s ' "$DIM" "${1:-Press Enter to continue}" "$RESET"
    read -r _ || true
}

# execute <cmd> [args...] — run it, or under --dry-run only show it.
execute() {
    if [ "$DRY" = 1 ]; then
        printf '  %s→ would run:%s %s\n' "$GREEN" "$RESET" "$*"
        return 0
    fi
    printf '  %s$%s %s\n' "$DIM" "$RESET" "$*"
    "$@"
}

# skip "text" — record a step the human still has to do.
skip() {
    warn "$1"
    SKIPPED+=("$1")
}

# finish — the closing summary, listing everything left to do by hand.
finish() {
    clear_screen
    printf '\n%s%s  ✓ First-run setup finished%s\n' "$BOLD" "$GREEN" "$RESET"
    if ((${#SKIPPED[@]})); then
        printf '\n'
        warn "still to do by hand:"
        local s
        for s in "${SKIPPED[@]}"; do note "  - $s"; done
    fi
    printf '\n'
}

# is_arch — true on Arch / CachyOS, the only distro the package lists target.
is_arch() {
    [ -f "$ARCH_RELEASE" ] && return 0
    [ -r "$OS_RELEASE" ] || return 1
    # shellcheck disable=SC1090  # the path is overridable for tests
    . "$OS_RELEASE" 2>/dev/null || return 1
    case "${ID:-} ${ID_LIKE:-}" in
        *arch*) return 0 ;;
        *) return 1 ;;
    esac
}

# select_shell — print the login shell to use, or fail when there is nothing to
# offer. Lists $SHELLS_FILE interactively; under --yes/--dry-run it picks fish,
# the rice's shell, when it is installed.
select_shell() {
    local -a shells=()
    local line s
    if [ -r "$SHELLS_FILE" ]; then
        while IFS= read -r line; do
            line="${line%%#*}"
            line="${line//[[:space:]]/}"
            [ -n "$line" ] && shells+=("$line")
        done <"$SHELLS_FILE"
    fi
    ((${#shells[@]})) || return 1

    local fish=""
    for s in "${shells[@]}"; do
        case "$s" in
            */fish) fish="$s" ;;
        esac
    done

    if [ "$YES" = 1 ] || [ "$DRY" = 1 ]; then
        [ -n "$fish" ] || return 1
        printf '%s\n' "$fish"
        return 0
    fi

    printf '  Available login shells:\n' >&2
    local i=1
    for s in "${shells[@]}"; do
        printf '  %s•%s %s) %s\n' "$BLUE" "$RESET" "$i" "$s" >&2
        i=$((i + 1))
    done
    local choice=""
    printf '  %s? Login shell number (Enter to skip):%s ' "$YELLOW" "$RESET" >&2
    read -r choice || true
    case "$choice" in
        '' | *[!0-9]*) return 1 ;;
    esac
    ((choice >= 1 && choice <= ${#shells[@]})) || return 1
    printf '%s\n' "${shells[choice - 1]}"
}

# ── Stages ───────────────────────────────────────────────────────────────────

run_wizard() {
    printf '\n%s%s  First-run setup%s\n' "$BOLD" "$BLUE" "$RESET"
    printf '%s  %s stages · a confirmation before each · Ctrl-C to stop%s\n\n' \
        "$DIM" "$TOTAL_STAGES" "$RESET"
    pause "Ready to start?"

    # 1. Preflight — confirm the ground we stand on, then show the plan.
    stage "Preflight"
    say "clone: $ROOT"
    if [ -e "$ROOT/.git" ]; then
        note "git clone detected"
    else
        warn "no .git here — run this from a clone of the repository"
    fi
    if is_arch; then
        note "distro: Arch / CachyOS"
    else
        warn "not Arch/CachyOS — the package stage will be skipped"
    fi
    say "plan:"
    step "packages   config/hypr/bootstrap.sh   (sudo)"
    step "configs    ./install.sh --no-packages"
    step "optional   ./install.sh --system | --timer | chsh"
    step "secrets    you copy the *.EXAMPLE files with your keys"
    step "verify     scripts/doctor.sh && make test"
    pause "Start the stages?"

    # 2. Packages — the official + AUR list, via bootstrap.sh's sudo pacman.
    stage "Packages (Arch / CachyOS)"
    if [ -z "$PACMAN_BIN" ]; then
        note "pacman not found — skipping"
        skip "install the packages from $ROOT/config/hypr/packages.txt"
    elif [ ! -x "$ROOT/config/hypr/bootstrap.sh" ]; then
        note "config/hypr/bootstrap.sh is missing — skipping"
        skip "install the packages from $ROOT/config/hypr/packages.txt"
    elif confirm "Install packages now? This runs sudo pacman and the AUR helper"; then
        execute "$ROOT/config/hypr/bootstrap.sh" ||
            warn "bootstrap.sh reported a problem — review its output"
    else
        skip "install packages: $ROOT/config/hypr/bootstrap.sh"
    fi

    # 3. Configs — symlink the repo into $HOME (install.sh backs up conflicts).
    stage "Link configs"
    if confirm "Symlink this repo's configs into \$HOME (existing files are backed up)?"; then
        execute "$ROOT/install.sh" --no-packages ||
            warn "install.sh reported a problem — review its output"
    else
        skip "link configs: $ROOT/install.sh --no-packages"
    fi

    # 4. Optional: the system tuning configs (zram, oomd, ananicy, irqbalance).
    stage "System configs (optional)"
    note "zram, systemd-oomd, ananicy-cpp, irqbalance, keyd — needs sudo"
    if confirm "Install the system configs too?"; then
        execute "$ROOT/install.sh" --system ||
            warn "install.sh --system reported a problem — review its output"
    else
        note "skipped"
    fi

    # 5. Optional: the systemd auto-backup timer.
    stage "Auto-backup timer (optional)"
    note "systemd timer that snapshots local edits to the 'snapshots' branch"
    if confirm "Enable the auto-backup timer?"; then
        execute "$ROOT/install.sh" --timer ||
            warn "install.sh --timer reported a problem — review its output"
    else
        note "skipped"
    fi

    # 6. Optional: the login shell, offered from $SHELLS_FILE.
    stage "Login shell (optional)"
    local shell=""
    if ! shell="$(select_shell)"; then
        note "no login shell offered (or none chosen) — skipping"
    elif confirm "Change the login shell to $shell?"; then
        note "chsh may ask for your password"
        execute chsh -s "$shell" ||
            warn "chsh failed — change it by hand: chsh -s $shell"
    else
        skip "change the login shell: chsh -s $shell"
    fi

    # 7. Secrets — explain the by-hand copy; never create or commit them.
    stage "Secrets (you do this by hand)"
    say "Secrets never live in this repo. Copy the tracked examples and fill in"
    say "your own keys:"
    step "cp $ROOT/fish/secrets.fish.EXAMPLE ~/.secrets.fish"
    step "cp $ROOT/claude/settings.local.json.EXAMPLE ~/.claude/settings.local.json"
    note "both targets are covered by .gitignore"
    pause "Press Enter once copied (or to skip for now)"

    # 8. Verify — the health check and the test suite.
    stage "Verify"
    if confirm "Run the health check and the test suite?"; then
        execute "$ROOT/scripts/doctor.sh" ||
            warn "doctor.sh reported issues — review its output"
        execute make -C "$ROOT" test ||
            warn "make test failed — review its output"
    else
        skip "verify: $ROOT/scripts/doctor.sh && make -C $ROOT test"
    fi

    finish
}

run_wizard "$@"
