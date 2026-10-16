#!/usr/bin/env bash
# check-palette-targets.sh — guard against drift between the palette module's
# target table and everything that has to agree with it.
#
#   scripts/check-palette-targets.sh
#
# Fails (exit 1) when any of these no longer hold:
#   1. every target in palette.sh's TARGETS list is a configured wallust
#      destination (so nothing imports a colour file nothing writes);
#   2. every configured wallust destination under ~/.config is a target (so the
#      generator never writes a file the module doesn't own);
#   3. every target is ignored in .gitignore;
#   4. every target is marked generated (linguist-generated) in .gitattributes;
#   5. palette.sh binds its light palette to targets by name (target_for <key>),
#      not by position in TARGETS, and the named consumers cover every target.
#
# wallust also writes mako/starship/tofi into ~/.cache/wallust/; those are not
# module targets and are deliberately ignored here. The module owns the
# ~/.config outputs only.
#
# The input paths can be overridden with CHECK_PALETTE_SH / CHECK_WALLUST_TOML /
# CHECK_GITIGNORE / CHECK_GITATTRIBUTES, which the tests use to provoke drift
# without editing the real table.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PALETTE_SH="${CHECK_PALETTE_SH:-$ROOT/config/hypr/scripts/palette.sh}"
WALLUST_TOML="${CHECK_WALLUST_TOML:-$ROOT/config/wallust/wallust.toml}"
GITIGNORE="${CHECK_GITIGNORE:-$ROOT/.gitignore}"
GITATTRIBUTES="${CHECK_GITATTRIBUTES:-$ROOT/.gitattributes}"

for f in "$PALETTE_SH" "$WALLUST_TOML" "$GITIGNORE" "$GITATTRIBUTES"; do
    [ -f "$f" ] || {
        echo "check-palette-targets: missing $f" >&2
        exit 1
    }
done

status=0
err() {
    echo "check-palette-targets: $*" >&2
    status=1
}

# module_targets — config-relative paths from palette.sh's TARGETS array, the
# single place the module lists the files a palette writes.
module_targets() {
    sed -n '/^TARGETS=(/,/^)/p' "$PALETTE_SH" |
        grep -o '"\$CONFIG/[^"]*"' |
        sed -E 's#^"\$CONFIG/##; s#"$##' || true
}

# generator_targets — the ~/.config destinations from wallust.toml, normalised
# to config-relative paths. The ~/.cache outputs are dropped: not module targets.
generator_targets() {
    grep -o 'dst = "[^"]*"' "$WALLUST_TOML" |
        sed -E 's#^dst = "##; s#"$##' |
        grep '^~/.config/' |
        sed -E 's#^~/.config/##' || true
}

# gitattributes_marks_generated <rel> — true when a linguist-generated pattern
# in .gitattributes covers config-relative path <rel>.
gitattributes_marks_generated() {
    local rel="config/$1" pat attrs
    while read -r pat attrs; do
        [ -n "$pat" ] || continue
        case "$pat" in '#'*) continue ;; esac
        case "$attrs" in
            *'-linguist-generated'*) continue ;;
            *linguist-generated*) ;;
            *) continue ;;
        esac
        # shellcheck disable=SC2254 # the .gitattributes field IS a glob on purpose
        case "$rel" in $pat) return 0 ;; esac
    done <"$GITATTRIBUTES"
    return 1
}

mapfile -t module < <(module_targets | sort -u)
mapfile -t generator < <(generator_targets | sort -u)

if [ "${#module[@]}" -eq 0 ]; then
    echo "check-palette-targets: could not read any targets from $PALETTE_SH" >&2
    exit 1
fi
if [ "${#generator[@]}" -eq 0 ]; then
    echo "check-palette-targets: could not read any ~/.config destinations from $WALLUST_TOML" >&2
    exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
printf '%s\n' "${module[@]}" >"$tmp/module"
printf '%s\n' "${generator[@]}" >"$tmp/generator"

# 1 + 2. target table and generator destinations must be the same set.
while IFS= read -r t; do
    [ -n "$t" ] || continue
    err "target '$t' is in the module table but not a wallust destination"
done < <(comm -13 "$tmp/generator" "$tmp/module")
while IFS= read -r t; do
    [ -n "$t" ] || continue
    err "wallust destination '$t' is not in the module target table"
done < <(comm -23 "$tmp/generator" "$tmp/module")

# 3 + 4. version-control ignore entry and generated-file metadata per target.
while IFS= read -r t; do
    [ -n "$t" ] || continue
    grep -qxF "config/$t" "$GITIGNORE" ||
        err "target 'config/$t' has no ignore entry in .gitignore"
    gitattributes_marks_generated "$t" ||
        err "target 'config/$t' is not marked linguist-generated in .gitattributes"
done < <(printf '%s\n' "${module[@]}")

# 5. light content must be bound to consumers by name (target_for <key>), never
#    by position in TARGETS; each named consumer must select exactly one target
#    and together they must cover the whole table.
if grep -qE 'TARGETS\[[0-9]+\]' "$PALETTE_SH"; then
    err "palette.sh indexes TARGETS by position; bind content to named targets"
fi
mapfile -t keys < <(grep -oE 'target_for [A-Za-z0-9_-]+' "$PALETTE_SH" |
    awk '{print $2}' | sort -u)
if [ "${#keys[@]}" -eq 0 ]; then
    err "palette.sh binds no named targets (expected target_for <key> calls)"
else
    bound=()
    for k in "${keys[@]}"; do
        matches=0
        match=""
        for t in "${module[@]}"; do
            case "/$t/" in
                */"$k"/*)
                    matches=$((matches + 1))
                    match="$t"
                    ;;
            esac
        done
        if [ "$matches" -eq 1 ]; then
            bound+=("$match")
        else
            err "named target '$k' selects $matches targets (want exactly 1)"
        fi
    done
    if [ "${#bound[@]}" -gt 0 ]; then
        printf '%s\n' "${bound[@]}" | sort -u >"$tmp/bound"
        diff -q "$tmp/module" "$tmp/bound" >/dev/null ||
            err "named targets do not cover exactly the module target table"
    fi
fi

if [ "$status" -eq 0 ]; then
    echo "check-palette-targets: module table, wallust config and vcs metadata agree (${#module[@]} targets)"
else
    echo "check-palette-targets: the target table and its generator/vcs metadata drifted — fix the above" >&2
fi
exit "$status"
