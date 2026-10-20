#!/usr/bin/env bash
# battery.sh — уведомления о разряде без демонов и root.
#   battery.sh status      батарея, заряд, пороги
#   battery.sh check       один проход: уведомить, если пора
#   battery.sh daemon      check раз в GOTHIC_BATTERY_INTERVAL секунд (60)
#
# Пороги 20/10/5% срабатывают по одному разу за цикл разряда; при подключении
# зарядки отметки сбрасываются. На машине без BAT* daemon сразу выходит.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$CONFIG/hypr"
POWER_SUPPLY="${GOTHIC_POWER_SUPPLY:-/sys/class/power_supply}"
MARKER="$STATE/battery-notified"
INTERVAL="${GOTHIC_BATTERY_INTERVAL:-60}"

usage() {
    cat >&2 <<'EOF'
usage: battery.sh status
       battery.sh check
       battery.sh daemon
EOF
    exit 2
}

battery_dir() {
    local dir
    for dir in "$POWER_SUPPLY"/BAT*; do
        [ -r "$dir/capacity" ] || continue
        printf '%s\n' "$dir"
        return 0
    done
    return 1
}

note() {
    local urgency="$1" message="$2"
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -u "$urgency" "Батарея" "$message" >/dev/null 2>&1 || true
}

already() {
    [ -r "$MARKER" ] && grep -qx "$1" "$MARKER" 2>/dev/null
}

mark() {
    mkdir -p "$STATE"
    printf '%s\n' "$1" >>"$MARKER"
}

check() {
    local dir capacity status threshold urgency
    dir="$(battery_dir)" || {
        rm -f "$MARKER"
        return 0
    }
    capacity="$(cat "$dir/capacity" 2>/dev/null || echo 0)"
    status="$(cat "$dir/status" 2>/dev/null || echo Unknown)"
    case "$capacity" in '' | *[!0-9]*) return 0 ;; esac

    case "$status" in
        Charging | Full)
            rm -f "$MARKER"
            return 0
            ;;
        Discharging) ;;
        *) return 0 ;;
    esac

    # Один порог за проход: самый близкий сверху. Если ноутбук проснулся на 4%,
    # нет смысла показывать 20%, 10% и 5% подряд — важно только 5%.
    threshold=""
    for threshold in 5 10 20; do
        [ "$capacity" -le "$threshold" ] && break
        threshold=""
    done
    [ -n "$threshold" ] || return 0
    already "$threshold" && return 0

    urgency=normal
    [ "$threshold" = 5 ] && urgency=critical
    note "$urgency" "${capacity}% — подключи зарядку"
    mark "$threshold"
}

status() {
    local dir capacity state
    if ! dir="$(battery_dir)"; then
        printf 'батарея: нет\n'
        return 0
    fi
    capacity="$(cat "$dir/capacity" 2>/dev/null || echo '?')"
    state="$(cat "$dir/status" 2>/dev/null || echo '?')"
    printf 'батарея: %s%% (%s)\n' "$capacity" "$state"
    if [ -r "$MARKER" ]; then
        printf 'отмечено: %s\n' "$(tr '\n' ' ' <"$MARKER" | sed 's/ $//')"
    fi
}

daemon() {
    trap 'exit 0' TERM INT
    while :; do
        check
        sleep "$INTERVAL"
    done
}

case "${1:-status}" in
    status | "") status ;;
    check) check ;;
    daemon) daemon ;;
    *) usage ;;
esac
