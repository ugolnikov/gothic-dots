#!/usr/bin/env bash
# scan-secrets.sh — fail when files look like they carry a secret.
#
# Used in two places: the pre-commit hook (blocking) and
# scripts/dotfiles-backup.sh (defense in depth before an automatic push).
#
#   scripts/scan-secrets.sh           scan the staged files (default)
#   scripts/scan-secrets.sh --all     scan every tracked file
#
# *.EXAMPLE templates and this script itself are skipped on purpose.
set -euo pipefail

MODE="staged"
[ "${1:-}" = "--all" ] && MODE="all"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ "$MODE" = "staged" ] && git rev-parse --git-dir >/dev/null 2>&1; then
    mapfile -t files < <(git diff --cached --name-only --diff-filter=ACM)
else
    mapfile -t files < <(git ls-files)
fi

# Distinctive shapes of common credentials.
shapes='AKIA[0-9A-Z]{16}'
shapes="$shapes|-----BEGIN [A-Z ]*PRIVATE KEY-----"
shapes="$shapes|sk-[A-Za-z0-9_-]{20,}"
shapes="$shapes|gh[pousr]_[A-Za-z0-9]{36,}"
shapes="$shapes|github_pat_[A-Za-z0-9_]{60,}"
shapes="$shapes|xox[baprs]-[A-Za-z0-9-]{10,}"
shapes="$shapes|AIza[0-9A-Za-z_-]{35}"

# Generic "key = <long value>" assignments for named credentials.
assign='(api[_-]?key|secret|token|passwd|password)[[:space:]]*[:=][[:space:]]*"?[A-Za-z0-9/_.-]{12,}'

status=0
for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    case "$f" in
        *.EXAMPLE | scripts/scan-secrets.sh) continue ;;
    esac
    if grep -nEI -- "$shapes" "$f" >&2; then
        echo "scan-secrets: possible secret in $f" >&2
        status=1
    fi
    if grep -nEI -- "$assign" "$f" >&2; then
        echo "scan-secrets: possible credential in $f" >&2
        status=1
    fi
done

if [ "$status" -ne 0 ]; then
    echo "scan-secrets: refusing — remove the value or add a *.EXAMPLE template" >&2
fi
exit "$status"
