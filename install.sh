#!/usr/bin/env bash
# install.sh — safe auto-install of the dotfiles.
#   ./install.sh                 install packages (Arch/CachyOS) and link configs
#   ./install.sh --no-packages   link configs only
#   ./install.sh --timer         also enable the systemd auto-backup
#   ./install.sh --system        also install system configs (zram/oomd/ananicy/irqbalance/keyd)
#   ./install.sh --force         overwrite existing targets without a backup
#   ./install.sh --dry-run       print the steps, change nothing
#   ./install.sh --uninstall     remove this repo's symlinks (inverse of install)
#
# Safety: never destroys your existing configs. Anything that would be replaced
# is moved to ~/.dotfiles-backup/<timestamp>/ first, keeping its relative path.
# Re-running is idempotent: our own symlinks are refreshed, not backed up.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

PKGS=1
TIMER=0
DRY=0
FORCE=0
SYSTEM=0
UNINSTALL=0
for a in "$@"; do
    case "$a" in
        --no-packages) PKGS=0 ;;
        --timer) TIMER=1 ;;
        --system) SYSTEM=1 ;;
        --dry-run) DRY=1 ;;
        --force) FORCE=1 ;;
        --uninstall) UNINSTALL=1 ;;
        -h | --help) sed -n '2,13p' "$0"; exit 0 ;;
        *)
            echo "unknown argument: $a" >&2
            exit 2
            ;;
    esac
done

BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
LINKED=0
BACKED=0

say() { printf '  %s\n' "$*"; }
run() {
    if [ "$DRY" = 1 ]; then
        printf '  %s' "$1"
        shift
        printf ' %s' "$@"
        printf '\n'
    else
        "$@"
    fi
}

# is_ours <path> — true when the path is a symlink into this repository.
is_ours() {
    [ -L "$1" ] || return 1
    local t
    t="$(readlink -f "$1" 2>/dev/null || true)"
    case "$t" in "$DIR"/*) return 0 ;; *) return 1 ;; esac
}

# link <src> <dst> — symlink src at dst, backing up anything real in the way.
link() {
    local src="$1" dst="$2" rel
    rel="${dst#"$HOME"/}"

    if is_ours "$dst"; then
        run ln -sfnT "$src" "$dst"
        LINKED=$((LINKED + 1))
        return 0
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ "$FORCE" = 1 ]; then
            say "replace  $dst  (--force, no backup)"
            run rm -rf -- "$dst"
        else
            say "backup   $dst  ->  $BACKUP/$rel"
            run mkdir -p "$BACKUP/$(dirname "$rel")"
            run mv -- "$dst" "$BACKUP/$rel"
            BACKED=$((BACKED + 1))
        fi
    fi

    run mkdir -p "$(dirname "$dst")"
    run ln -sfnT "$src" "$dst"
    LINKED=$((LINKED + 1))
}

# unlink <path> — remove a symlink only if it points into this repository.
unlink() {
    if is_ours "$1"; then
        say "remove   $1"
        run rm -f -- "$1"
        LINKED=$((LINKED + 1))
    fi
}

if [ "$DRY" = 1 ]; then echo "==> dry run (no changes)"; fi
if [ "$(id -u)" = 0 ]; then
    echo "==> note: running as root — configs will be linked into $HOME"
fi
echo "==> dotfiles: $DIR"

# 0. --uninstall: remove only our own symlinks, leave everything else alone.
if [ "$UNINSTALL" = 1 ]; then
    echo "==> uninstall: removing symlinks into $DIR"
    for d in "$DIR"/config/*/; do
        unlink "$HOME/.config/$(basename "$d")"
    done
    unlink "$HOME/.config/starship.toml"
    for f in .vimrc .tmux.conf .gitconfig .editorconfig .bashrc .profile; do
        unlink "$HOME/$f"
    done
    unlink "$HOME/.config/fish"
    unlink "$HOME/.claude/settings.json"
    for b in "$DIR"/bin/*; do
        [ -e "$b" ] || continue
        unlink "$HOME/.local/bin/$(basename "$b")"
    done
    if [ -d "$DIR/.git" ] && command -v git >/dev/null 2>&1; then
        run git -C "$DIR" config --unset core.hooksPath 2>/dev/null || true
    fi
    echo "==> done: $LINKED removed"
    last=""
    for d in "$HOME"/.dotfiles-backup/*/; do
        [ -d "$d" ] && last="$d"
    done
    if [ -n "$last" ]; then
        echo "    earlier configs (if any) are in $last"
    fi
    exit 0
fi

# 1. Packages (official + AUR) — Arch/CachyOS only.
if [ "$PKGS" = 1 ] && command -v pacman >/dev/null 2>&1 && [ -x "$DIR/config/hypr/bootstrap.sh" ]; then
    run "$DIR/config/hypr/bootstrap.sh"
else
    echo "==> packages: skipped (not Arch/CachyOS or --no-packages)"
fi

# 2. ~/.config/<app>
for d in "$DIR"/config/*/; do
    name="$(basename "$d")"
    link "${d%/}" "$HOME/.config/$name"
done
# config/starship.toml is a file, not a directory
link "$DIR/config/starship.toml" "$HOME/.config/starship.toml"

# 2b. Per-machine Hyprland monitor overrides: seed an ignored copy from the
# tracked example so the source in monitors.conf never dangles.
_hypr_local="$HOME/.config/hypr/conf.d/monitors.local.conf"
if [ ! -e "$_hypr_local" ] && [ -e "$_hypr_local.EXAMPLE" ]; then
    run cp "$_hypr_local.EXAMPLE" "$_hypr_local"
fi

# 3. Home dotfiles
for f in .vimrc .tmux.conf .gitconfig .editorconfig; do
    [ -e "$DIR/$f" ] && link "$DIR/$f" "$HOME/$f"
done
for f in .bashrc .profile; do
    link "$DIR/bash/$f" "$HOME/$f"
done

# 4. Package dirs outside ~/.config
link "$DIR/fish" "$HOME/.config/fish"
[ -e "$DIR/claude/settings.json" ] && link "$DIR/claude/settings.json" "$HOME/.claude/settings.json"

# 5. bin -> ~/.local/bin (already on PATH)
for b in "$DIR"/bin/*; do
    [ -e "$b" ] || continue
    link "$b" "$HOME/.local/bin/$(basename "$b")"
done

# 6. Executable bits
run chmod +x "$DIR"/config/hypr/scripts/*.sh "$DIR"/config/hypr/bootstrap.sh \
    "$DIR"/scripts/*.sh "$DIR"/scripts/server/*.sh "$DIR"/.githooks/pre-commit 2>/dev/null || true

# 7. Font cache + bat theme cache
if command -v fc-cache >/dev/null 2>&1; then run fc-cache -f; fi
if command -v bat >/dev/null 2>&1; then run bat cache --build; fi

# 8. vim-plug (only if missing)
if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
    echo "==> vim-plug"
    run bash -c 'curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
fi

# 9. Auto-backup (systemd), with --timer
if [ "$TIMER" = 1 ] && command -v systemctl >/dev/null 2>&1; then
    echo "==> auto-backup (systemd)"
    # The unit ships with @DOTFILES@/@USER@/@HOME@ placeholders, so it works
    # from any clone path and runs as the repo owner rather than root.
    _run_user="${SUDO_USER:-$(id -un)}"
    _run_home="$(getent passwd "$_run_user" | cut -d: -f6)"
    [ -n "$_run_home" ] || _run_home="$HOME"
    _unit="$(mktemp)"
    sed -e "s#@DOTFILES@#${DIR}#g" \
        -e "s#@USER@#${_run_user}#g" \
        -e "s#@HOME@#${_run_home}#g" \
        "$DIR/systemd/dotfiles-backup.service" >"$_unit"
    run sudo cp "$_unit" /etc/systemd/system/dotfiles-backup.service
    run rm -f "$_unit"
    run sudo cp "$DIR"/systemd/dotfiles-backup.timer /etc/systemd/system/
    run sudo systemctl daemon-reload
    run sudo systemctl enable --now dotfiles-backup.timer
fi

# 10. System tuning (--system): zram, systemd-oomd, ananicy-cpp, irqbalance
if [ "$SYSTEM" = 1 ]; then
    echo "==> system configs (zram/oomd/ananicy/irqbalance)"
    run "$DIR/config/hypr/scripts/system-setup.sh"
fi

# 11. Git hooks: enable the repo's pre-commit guard (secret scan + syntax).
if [ -d "$DIR/.git" ] && command -v git >/dev/null 2>&1; then
    run git -C "$DIR" config core.hooksPath .githooks
fi

echo "==> done: $LINKED linked, $BACKED backed up"
if [ "$BACKED" -gt 0 ] && [ "$DRY" = 0 ]; then
    echo "    your previous configs are in $BACKUP"
fi
echo "    restart your shell; for Hyprland, log out and back in."
