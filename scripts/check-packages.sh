#!/usr/bin/env bash
# check-packages.sh — verify the package lists actually resolve.
#
#   scripts/check-packages.sh
#
# Checks every entry of config/hypr/packages.txt against the official Arch
# repositories and every entry of config/hypr/aur.packages.txt against the AUR,
# so a typo or a renamed/dropped package (e.g. one that moved between repos) is
# caught before `bootstrap.sh` tries to install it.
#
# Needs network access. A lookup that fails or returns something that is not
# JSON is reported as a warning (not a failure), so an offline run or a proxy
# stays quiet instead of producing false "missing" lines. Not part of CI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_LIST="$ROOT/config/hypr/packages.txt"
AUR_LIST="$ROOT/config/hypr/aur.packages.txt"

# list <file> — package names, with comments and blank lines stripped.
list() {
    grep -vE '^[[:space:]]*(#|$)' "$1" 2>/dev/null |
        sed -E 's/[[:space:]]*#.*$//' |
        awk 'NF'
}

# Each lookup returns 0 (found), 1 (not found) or 2 (network/parse error).
arch_lookup() {
    local res
    res="$(curl -fsSL "https://archlinux.org/packages/search/json/?name=$1" 2>/dev/null)" || return 2
    python3 -c '
import json, sys
try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(2)
sys.exit(0 if data.get("results") else 1)
' "$res"
}

aur_lookup() {
    local res
    res="$(curl -fsSL "https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=$1" 2>/dev/null)" || return 2
    python3 -c '
import json, sys
try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(2)
sys.exit(0 if data.get("resultcount", 0) > 0 else 1)
' "$res"
}

status=0
warned=0

check() { # check <label> <fn> <pkg>
    local label="$1" fn="$2" pkg="$3" rc=0
    "$fn" "$pkg" || rc=$?
    case "$rc" in
        0) printf '  ok    %s %s\n' "$label" "$pkg" ;;
        1)
            printf '  MISS  %s %s\n' "$label" "$pkg" >&2
            status=1
            ;;
        *)
            printf '  warn  %s %s (API unreachable — skipped)\n' "$label" "$pkg" >&2
            warned=1
            ;;
    esac
}

echo "==> Arch repos (packages.txt)"
while read -r pkg; do
    [ -n "$pkg" ] || continue
    check repo arch_lookup "$pkg"
done < <(list "$REPO_LIST")

echo "==> AUR (aur.packages.txt)"
while read -r pkg; do
    [ -n "$pkg" ] || continue
    check aur aur_lookup "$pkg"
done < <(list "$AUR_LIST")

if [ "$status" -eq 0 ]; then
    echo "check-packages: all names resolve"
    [ "$warned" -eq 1 ] && echo "check-packages: some lookups were skipped (see warnings above)"
else
    echo "check-packages: unknown packages found — fix the lists above" >&2
fi
exit "$status"
