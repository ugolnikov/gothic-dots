#!/usr/bin/env bash
# check-coverage.sh — every tracked, user-facing file must be in the link plan,
# so a new home dotfile (or app dir) can't be silently forgotten.
#
#   scripts/check-coverage.sh
#
# It reads the link set straight from scripts/link-plan.sh, the single
# definition of what gets linked where, so the check can never drift from what
# the installer links. A file is "covered" when it is one of the plan's
# sources, or lives under one. Everything the plan deliberately does not link
# (docs, tooling, --system/--timer inputs, *.EXAMPLE templates meant to be
# copied by hand) is allow-listed below.
#
# CHECK_COVERAGE_PLAN overrides the plan command; the tests use it to provoke
# drift without editing the real plan or the installer.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PLAN="${CHECK_COVERAGE_PLAN:-$ROOT/scripts/link-plan.sh}"

# Sources the link plan links, read from its `src<TAB>dst` output.
linked=()
while read -r src _dst; do
    [ -n "$src" ] && linked+=("$src")
done < <("$PLAN" 2>/dev/null)

if [ "${#linked[@]}" -eq 0 ]; then
    echo "check-coverage: the link plan produced no links — aborting" >&2
    exit 1
fi

# Tracked paths that are intentionally not in the link plan.
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
        err "$f is tracked but the link plan never links it (add it, or allow-list it here)"
    fi
done < <(git ls-files)

if [ "$status" -eq 0 ]; then
    info "all tracked configs are covered by the link plan (${#linked[@]} links)"
else
    info "some files are not linked by the plan — fix the above" >&2
fi
exit "$status"
