#!/usr/bin/env bash
# check-coverage.sh — every tracked, user-facing file must be installed by
# install.sh, so a new home dotfile (or app dir) can't be silently forgotten.
#
#   scripts/check-coverage.sh
#
# It reads the symlink sources straight from `install.sh --no-packages
# --dry-run`, so the check can never drift from the installer itself. A file is
# "covered" when it is one of those sources, or lives under one. Everything the
# installer deliberately does not link (docs, tooling, --system/--timer inputs,
# *.EXAMPLE templates meant to be copied by hand) is allow-listed below.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Sources install.sh symlinks, parsed from its own dry run. Lines look like:
#   ln -sfnT /abs/src /abs/dst
linked=()
while read -r src _dst; do
    [ -n "$src" ] && linked+=("$src")
done < <(./install.sh --no-packages --dry-run 2>/dev/null | awk '/ln -sfnT/ {print $3, $4}')

if [ "${#linked[@]}" -eq 0 ]; then
    echo "check-coverage: install.sh dry-run produced no links — aborting" >&2
    exit 1
fi

# Tracked paths that are intentionally not symlinked by install.sh.
allow_files='^(AGENTS\.md|GLOSSARY\.md|CONTRIBUTING\.md|CODING_STANDARDS\.md|README\.md|LICENSE|Makefile|SECURITY\.md|install\.sh|\.gitignore|\.gitattributes|\.shellcheckrc|\.markdownlint\.jsonc|claude/settings\.local\.json\.EXAMPLE)$'
allow_dirs='^(docs|\.github|\.githooks|scripts|etc|systemd|tests)/'

is_linked() {
    local f="$ROOT/$1" s
    for s in "${linked[@]}"; do
        if [ "$f" = "$s" ]; then return 0; fi
        case "$f" in "$s"/*) return 0 ;; esac
    done
    return 1
}

status=0
info() { printf 'check-coverage: %s\n' "$*"; }
err() {
    printf 'check-coverage: %s\n' "$*" >&2
    status=1
}

while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s' "$f" | grep -Eq "$allow_files" && continue
    printf '%s' "$f" | grep -Eq "$allow_dirs" && continue
    if ! is_linked "$f"; then
        err "$f is tracked but install.sh never links it (add it, or allow-list it here)"
    fi
done < <(git ls-files)

if [ "$status" -eq 0 ]; then
    info "all tracked configs are covered by install.sh (${#linked[@]} links)"
else
    info "some files are not installed by install.sh — fix the above" >&2
fi
exit "$status"
