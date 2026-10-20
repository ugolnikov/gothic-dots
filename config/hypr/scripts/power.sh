#!/usr/bin/env bash
# power.sh — профиль питания через power-profiles-daemon.
#   power.sh status
#   power.sh saver|balanced|performance
#   power.sh cycle                 saver → balanced → performance → saver
#   power.sh menu                  выбрать профиль в rofi
#
# PPD — единственный бэкенд: TLP с ним конфликтует. Если powerprofilesctl нет,
# модуль честно говорит, что установить, и не притворяется, что переключил.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
ROFI_THEME="$CONFIG/rofi/settings.rasi"
PPD="${POWER_PROFILES_CMD:-powerprofilesctl}"

usage() {
    cat >&2 <<'EOF'
usage: power.sh status
       power.sh saver|balanced|performance
       power.sh cycle
       power.sh menu
EOF
    exit 2
}

note() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "Питание" "$1" >/dev/null 2>&1 || true
}

have_ppd() {
    command -v "$PPD" >/dev/null 2>&1
}

current() {
    have_ppd || return 0
    "$PPD" get 2>/dev/null || true
}

require_ppd() {
    have_ppd && return 0
    echo "power.sh: нужен power-profiles-daemon (powerprofilesctl)" >&2
    note "установи power-profiles-daemon"
    exit 1
}

set_profile() {
    local profile="$1"
    case "$profile" in saver | balanced | performance) ;; *) usage ;; esac
    require_ppd
    "$PPD" set "$profile"
}

cycle() {
    local now
    now="$(current)"
    case "$now" in
        saver) set_profile balanced ;;
        balanced) set_profile performance ;;
        performance) set_profile saver ;;
        *) set_profile balanced ;;
    esac
}

menu() {
    local now choice
    require_ppd
    command -v rofi >/dev/null 2>&1 || {
        echo "power.sh: rofi не установлен" >&2
        exit 1
    }
    now="$(current)"
    choice="$(printf '%s\n' saver balanced performance |
        rofi -dmenu -i -p "Питание" -theme "$ROFI_THEME")" || exit 0
    [ -n "$choice" ] || exit 0
    set_profile "$choice"
}

status() {
    local now
    now="$(current)"
    if [ -z "$now" ]; then
        printf 'питание: power-profiles-daemon недоступен\n'
        return 0
    fi
    printf 'питание: %s\n' "$now"
}

case "${1:-status}" in
    status | "") status ;;
    saver | balanced | performance) set_profile "$1" ;;
    cycle) cycle ;;
    menu) menu ;;
    *) usage ;;
esac
