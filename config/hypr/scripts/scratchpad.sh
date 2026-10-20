#!/usr/bin/env bash
# scratchpad.sh — именованные выпадающие окна в special-workspace.
#   scratchpad.sh toggle <name>    показать / спрятать / запустить
#   scratchpad.sh menu             выбрать scratchpad в rofi
#   scratchpad.sh list             name — class
#   scratchpad.sh status           конфиг и число записей
#
# Конфиг: ~/.config/hypr/scratchpads.tsv, строки name<TAB>class<TAB>command.
# Единственное состояние — membership окна в special:<name>; PID-файлов нет.
# Если окно этого класса уже есть на обычном воркспейсе, оно переезжает в
# scratchpad, а не дублируется.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$CONFIG/hypr"
CONF="${SCRATCHPAD_CONF:-$STATE/scratchpads.tsv}"
HYPRCTL="${SCRATCHPAD_HYPRCTL:-hyprctl}"
ROFI_THEME="$CONFIG/rofi/settings.rasi"

usage() {
    cat >&2 <<'EOF'
usage: scratchpad.sh toggle <name>
       scratchpad.sh menu
       scratchpad.sh list
       scratchpad.sh status
EOF
    exit 2
}

note() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "Scratchpad" "$1" >/dev/null 2>&1 || true
}

dispatch() {
    "$HYPRCTL" dispatch "$@" >/dev/null 2>&1 || true
}

# entry <name> — "class<TAB>command" или код 1.
entry() {
    local name="$1" saved_name class command
    [ -r "$CONF" ] || return 1
    while IFS=$'\t' read -r saved_name class command; do
        case "$saved_name" in '' | '#'*) continue ;; esac
        [ "$saved_name" = "$name" ] || continue
        [ -n "$class" ] && [ -n "$command" ] || return 1
        printf '%s\t%s\n' "$class" "$command"
        return 0
    done <"$CONF"
    return 1
}

clients() {
    "$HYPRCTL" clients -j 2>/dev/null
}

addr_in_special() {
    clients | jq -r --arg ws "special:$1" '
        .[] | select(.workspace.name == $ws) | .address
    ' 2>/dev/null | head -n 1
}

addr_of_class() {
    clients | jq -r --arg class "$1" '
        .[] | select(.class == $class) | .address
    ' 2>/dev/null | head -n 1
}

toggle() {
    local name="$1" value class command addr
    value="$(entry "$name")" || {
        note "нет scratchpad «$name» в $CONF"
        exit 1
    }
    class="${value%%$'\t'*}"
    command="${value#*$'\t'}"

    addr="$(addr_in_special "$name")"
    if [ -n "$addr" ]; then
        dispatch togglespecialworkspace "$name"
        return 0
    fi

    addr="$(addr_of_class "$class")"
    if [ -n "$addr" ]; then
        dispatch movetoworkspacesilent "special:$name,address:$addr"
        dispatch togglespecialworkspace "$name"
        return 0
    fi

    dispatch exec "[workspace special:$name] $command"
    sleep "${SCRATCHPAD_DELAY:-0.4}"
    dispatch togglespecialworkspace "$name"
}

names() {
    [ -r "$CONF" ] || return 0
    awk -F '\t' '!/^#/ && NF >= 3 { print $1 }' "$CONF"
}

menu() {
    local choice
    command -v rofi >/dev/null 2>&1 || {
        echo "scratchpad.sh: rofi не установлен" >&2
        exit 1
    }
    [ -s "$CONF" ] || {
        note "создай $CONF"
        exit 1
    }
    choice="$(names | rofi -dmenu -i -p "Scratchpad" -theme "$ROFI_THEME")" || exit 0
    [ -n "$choice" ] || exit 0
    toggle "$choice"
}

list() {
    [ -r "$CONF" ] || return 0
    awk -F '\t' '!/^#/ && NF >= 3 { printf "%s — %s\n", $1, $2 }' "$CONF"
}

status() {
    local count=0
    if [ -r "$CONF" ]; then
        count="$(awk -F '\t' '!/^#/ && NF >= 3' "$CONF" | wc -l)"
    fi
    printf 'scratchpads: %s\n' "$CONF"
    printf 'записей: %s\n' "$count"
}

case "${1:-}" in
    toggle)
        [ -n "${2:-}" ] || usage
        toggle "$2"
        ;;
    menu) menu ;;
    list) list ;;
    status) status ;;
    *) usage ;;
esac
