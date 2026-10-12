#!/usr/bin/env bash
# gen-keybinds.sh — keep the keybind table in README.md in sync.
#
# The curated table lives in config/hypr/keybinds.tsv (tab-separated:
# "key cell <TAB> action"). Behaviour is still defined by
# config/hypr/conf.d/binds.conf; this file only stops the docs from drifting.
#
#   scripts/gen-keybinds.sh          rewrite README.md between the markers
#   scripts/gen-keybinds.sh --check  exit 1 if README is out of date (CI)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/config/hypr/keybinds.tsv"
README="$ROOT/README.md"
START='<!-- keybinds:start -->'
END='<!-- keybinds:end -->'

[ -f "$SRC" ] || {
    echo "gen-keybinds: missing $SRC" >&2
    exit 1
}

render() {
    printf '%s\n' "$START"
    printf '| Key | Action |\n'
    printf '|-----|--------|\n'
    while IFS=$'\t' read -r keys desc; do
        case "$keys" in '' | '#'*) continue ;; esac
        printf '| %s | %s |\n' "$keys" "$desc"
    done <"$SRC"
    printf '%s\n' "$END"
}

block="$(mktemp)"
render >"$block"
trap 'rm -f "$block"' EXIT

current() {
    awk -v s="$START" -v e="$END" '$0 == s { f = 1 } f { print } $0 == e { f = 0 }' "$README"
}

if [ "${1:-}" = "--check" ]; then
    if ! diff -u <(current) "$block" >/dev/null; then
        echo "gen-keybinds: README.md keybind table is out of date — run scripts/gen-keybinds.sh" >&2
        diff -u <(current) "$block" >&2 || true
        exit 1
    fi
    echo "gen-keybinds: up to date"
    exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$block" "$tmp"' EXIT
awk -v s="$START" -v e="$END" -v replfile="$block" '
    BEGIN { while ((getline l < replfile) > 0) repl = repl l ORS }
    $0 == s { printf "%s", repl; skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }
' "$README" >"$tmp"
mv "$tmp" "$README"
echo "gen-keybinds: updated $README"
