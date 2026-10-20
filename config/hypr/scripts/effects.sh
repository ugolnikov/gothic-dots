#!/usr/bin/env bash
# effects.sh — эффекты композитора, которые можно переключать на лету.
#   effects.sh animations [on|off|toggle|status]
#   effects.sh status
#
# Модуль владеет только animations.dynamic.conf и его применением; базовые
# значения (анимации выключены) остаются в conf.d/animations.conf. settings.sh
# и preset.sh ходят сюда, чтобы правило «один владелец» не ломалось.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
FILE="$CONFIG/hypr/conf.d/animations.dynamic.conf"

usage() {
    echo "usage: effects.sh animations [on|off|toggle|status] | status" >&2
    exit 2
}

die() {
    echo "effects.sh: $*" >&2
    exit 2
}

animations_status() {
    if [ -r "$FILE" ] && grep -q 'enabled = true' "$FILE"; then
        echo on
    else
        echo off
    fi
}

apply_animations() { # <true|false>
    mkdir -p "$(dirname "$FILE")"
    printf 'animations { enabled = %s }\n' "$1" >"$FILE"
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl keyword animations:enabled "$1" >/dev/null 2>&1 ||
            hyprctl reload >/dev/null 2>&1 || true
    fi
}

set_animations() {
    case "${1:-toggle}" in
        on) apply_animations true ;;
        off) apply_animations false ;;
        toggle)
            if [ "$(animations_status)" = on ]; then
                apply_animations false
            else
                apply_animations true
            fi
            ;;
        status) animations_status ;;
        *) usage ;;
    esac
}

main() {
    case "${1:-status}" in
        animations) set_animations "${2:-status}" ;;
        status) animations_status ;;
        *) usage ;;
    esac
}

main "$@"
