#!/usr/bin/env bash
# link-plan.sh — the single definition of what this repository links where.
#
#   scripts/link-plan.sh              print every link
#   scripts/link-plan.sh --only a,b   print only the named config apps
#
# Output is one `src<TAB>dst` per line, absolute paths, in a stable order.
# Consumers: install.sh links and unlinks exactly these pairs, the doctor
# derives its symlink checks from them, and the coverage guard reads them
# directly — so the set is defined here and nowhere else.
#
# Only links whose source exists are printed (install.sh guards its links the
# same way); otherwise the installer would leave a dangling symlink behind.
# HOME is the target's base, so tests redirect it to a throwaway tree.
set -euo pipefail

# LINK_PLAN_ROOT overrides the repo the plan is read from; tests use it to
# provoke a missing source without touching the real checkout.
ROOT="${LINK_PLAN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
HOME="${HOME:?link-plan.sh: HOME is not set}"

ONLY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --only)
            ONLY="${2:-}"
            if [ -z "$ONLY" ]; then
                echo "link-plan.sh: --only needs a comma-separated list of config apps" >&2
                exit 2
            fi
            shift
            ;;
        *)
            echo "link-plan.sh: unknown argument: $1" >&2
            echo "usage: link-plan.sh [--only a,b]" >&2
            exit 2
            ;;
    esac
    shift
done

# only_selected <name> — true when no --only was given, or <name> is listed.
only_selected() {
    [ -z "$ONLY" ] && return 0
    case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

# emit <src> <dst> — print one link, unless its source is missing.
emit() {
    [ -e "$1" ] || return 0
    printf '%s\t%s\n' "$1" "$2"
}

# 1. config/<app>/ -> ~/.config/<app>, filtered by --only.
for d in "$ROOT"/config/*/; do
    name="$(basename "$d")"
    only_selected "$name" || continue
    emit "${d%/}" "$HOME/.config/$name"
done
# config/starship.toml is a file, not a directory.
only_selected starship && emit "$ROOT/config/starship.toml" "$HOME/.config/starship.toml"

# 2. Home dotfiles and package dirs. --only skips these, exactly as it skips
#    install.sh's sections 3-5.
if [ -z "$ONLY" ]; then
    # The repo keeps tmux/git configs un-dotted while their targets are
    # dotfiles, so map src -> dst explicitly.
    for pair in ".vimrc:.vimrc" ".editorconfig:.editorconfig" \
        "tmux.conf:.tmux.conf" "gitconfig:.gitconfig"; do
        src="${pair%%:*}" dst="${pair##*:}"
        emit "$ROOT/$src" "$HOME/$dst"
    done
    for f in .bashrc .profile; do
        emit "$ROOT/bash/$f" "$HOME/$f"
    done

    # fish is a package dir outside the app-config tree.
    emit "$ROOT/fish" "$HOME/.config/fish"
    emit "$ROOT/claude/settings.json" "$HOME/.claude/settings.json"

    # bin -> ~/.local/bin (already on PATH).
    for b in "$ROOT"/bin/*; do
        [ -e "$b" ] || continue
        emit "$b" "$HOME/.local/bin/$(basename "$b")"
    done
fi
