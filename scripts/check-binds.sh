#!/usr/bin/env bash
# check-binds.sh — guard against drift between keybind docs and the config.
#
#   scripts/check-binds.sh
#
# Fails (exit 1) when any of these no longer hold:
#   1. every $variable used in binds.conf is defined;
#   2. every script a bind points at exists and is executable;
#   3. every dispatcher is a known Hyprland dispatcher;
#   4. every key used by a bind is mentioned in config/hypr/keybinds.tsv
#      (keys that are intentionally covered by an aggregate/abstract row are
#      allow-listed in $aggregate below).
#
# This complements gen-keybinds.sh: that one keeps README.md in sync with the
# tsv; this one keeps the tsv/scripts in sync with binds.conf.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BINDS="$ROOT/config/hypr/conf.d/binds.conf"
TSV="$ROOT/config/hypr/keybinds.tsv"
SCRIPTS_DIR="$ROOT/config/hypr/scripts"

[ -f "$BINDS" ] || { echo "check-binds: missing $BINDS" >&2; exit 1; }
[ -f "$TSV" ] || { echo "check-binds: missing $TSV" >&2; exit 1; }

status=0
err() { echo "check-binds: $*" >&2; status=1; }

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    printf '%s' "${s%"${s##*[![:space:]]}"}"
}

# Keys represented in keybinds.tsv by an aggregate/abstract row on purpose:
# workspace digits, vim/arrow movement, mouse scroll/drag, media and brightness.
aggregate='^(left|right|up|down|mouse_down|mouse_up|mouse:272|mouse:273)$'
aggregate="$aggregate"'|^(XF86Audio(Mute|Play|Next|Prev|RaiseVolume|LowerVolume))$'
aggregate="$aggregate"'|^(XF86MonBrightness(Up|Down))$'
aggregate="$aggregate"'|^[0-9]$'

# Hyprland dispatchers this config is allowed to use.
dispatchers=" exec exit killactive togglefloating pseudo togglesplit fullscreen movefocus movewindow resizeactive resizewindow workspace movetoworkspace togglespecialworkspace movetoworkspacesilent movewindowpixel centerwindow "

# 0. Variable definitions ($name = value).
declare -A vars=()
while IFS= read -r line; do
    case "$line" in
        \$*=*)
            name="$(trim "${line#\$}")"
            name="$(trim "${name%%=*}")"
            value="${line#*=}"
            vars["\$$name"]="$(trim "$value")"
            ;;
    esac
done <"$BINDS"

# tsv key column, lower-cased, for the coverage check.
tsv_keys="$(grep -v '^#' "$TSV" | cut -f1 | tr '[:upper:]' '[:lower:]')"

# check_script <token> — if a token is a path under the repo's hypr/scripts,
# require the file to exist and be executable.
check_script() {
    local tok="$1" rel script
    case "$tok" in
        */.config/hypr/scripts/*) rel="${tok#*/scripts/}" ;;
        *) return 0 ;;
    esac
    script="$SCRIPTS_DIR/$rel"
    [ -x "$script" ] || err "missing or not executable: $script (used as '$tok')"
}

while IFS= read -r line; do
    case "$line" in bind*=*) ;; *) continue ;; esac

    rhs="${line#*=}"
    rhs="$(trim "$rhs")"
    IFS=',' read -r mods key dispatcher args <<<"$rhs"
    mods="$(trim "$mods")"
    key="$(trim "$key")"
    dispatcher="$(trim "$dispatcher")"

    # 3. dispatcher
    case "$dispatchers" in
        *" $dispatcher "*) ;;
        *) err "unknown dispatcher '$dispatcher' in: $line" ;;
    esac

    # 4. key is documented (unless covered by an aggregate row)
    if ! printf '%s' "$key" | grep -Eqi -- "$aggregate"; then
        v="$key"
        [ "$v" = "comma" ] && v=","
        if ! printf '%s\n' "$tsv_keys" | grep -Fqi -- "$v"; then
            err "key '$key' (from: $line) is not listed in config/hypr/keybinds.tsv"
        fi
    fi

    # 1 + 2. variables and script references in the modifier and argument parts.
    for tok in $mods $args; do
        case "$tok" in
            \$*)
                if [ -z "${vars[$tok]:-}" ]; then
                    err "undefined variable '$tok' in: $line"
                else
                    check_script "${vars[$tok]}"
                fi
                ;;
            *)
                check_script "$tok"
                ;;
        esac
    done
done <"$BINDS"

if [ "$status" -ne 0 ]; then
    echo "check-binds: binds.conf and its documentation drifted — fix the above" >&2
fi
exit "$status"
