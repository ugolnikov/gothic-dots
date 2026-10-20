#!/usr/bin/env bash
# eventd.sh — реакции на события Hyprland: правила окон, шаринг, хуки,
# память раскладок по классу окна.
#   eventd.sh run [--fake FILE]     читать socket2 (или файл событий в тестах)
#   eventd.sh handle '<event>'      обработать одну строку события
#   eventd.sh status                что настроено и жив ли демон
#
# События приходят строками socket2: `openwindow>>ADDR,WS,CLASS,TITLE`,
# `closewindow>>ADDR`, `activewindow>>CLASS,TITLE`,
# `activelayout>>KEYBOARD,LAYOUT`, `monitoradded>>NAME`, `fullscreen>>ADDR,0|1`.
# Демон ничего не хранит сам: состояние шаринга — маркер, память раскладок —
# файл keyboard-memory.tsv, правила и шаринг читаются из конфигов, хуки —
# исполняемые файлы в eventd.d/.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$CONFIG/hypr"
SCRIPTS="${EVENTD_SCRIPTS:-$STATE/scripts}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${EVENTD_SCRIPTS:-}" ] && [ ! -d "$SCRIPTS" ]; then
    SCRIPTS="$HERE"
fi
HYPRCTL="${EVENTD_HYPRCTL:-hyprctl}"
CONTROLS="${EVENTD_CONTROLS:-$SCRIPTS/controls.sh}"
KEYBOARD_MEMORY="${EVENTD_KEYBOARD_MEMORY:-$SCRIPTS/keyboard-memory.sh}"
CONF="${EVENTD_CONF:-$STATE/eventd.conf}"
RULES="${EVENTD_RULES:-$STATE/windowrules.tsv}"
HOOKS="${EVENTD_HOOKS:-$STATE/eventd.d}"
SHARE_MARKER="$STATE/eventd-share"
SOCKET="${HYPRLAND_INSTANCE_SIGNATURE:+${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock}"

SHARE_CLASSES=""

usage() {
    cat >&2 <<'EOF'
usage: eventd.sh run [--fake FILE]
       eventd.sh handle '<event line>'
       eventd.sh status
EOF
    exit 2
}

die() {
    echo "eventd.sh: $*" >&2
    exit 2
}

note() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "События" "$1" >/dev/null 2>&1 || true
    return 0
}

load_config() {
    SHARE_CLASSES=""
    [ -r "$CONF" ] || return 0
    local line key value
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in '' | '#'*) continue ;; esac
        case "$line" in *=*) ;; *) continue ;; esac
        key="$(printf '%s' "${line%%=*}" | tr -d '[:space:]')"
        value="${line#*=}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        case "${key,,}" in
            share_classes) SHARE_CLASSES="$value" ;;
        esac
    done <"$CONF"
}

dispatch() {
    command -v "$HYPRCTL" >/dev/null 2>&1 || return 0
    "$HYPRCTL" dispatch "$@" >/dev/null 2>&1 || true
}

# apply_rule <address> <class> — первая подходящая строка windowrules.tsv
# (class<TAB>workspace) переносит окно. Класс сравнивается буквально.
apply_rule() {
    local addr="$1" class="$2" rule_class rule_ws
    [ -r "$RULES" ] || return 0
    while IFS=$'\t' read -r rule_class rule_ws; do
        case "$rule_class" in '' | '#'*) continue ;; esac
        [ -n "$rule_ws" ] || continue
        if [ "$rule_class" = "$class" ]; then
            dispatch movetoworkspacesilent "$rule_ws,address:$addr"
            return 0
        fi
    done <"$RULES"
}

share_matches() {
    local class="$1" pat
    [ -n "$SHARE_CLASSES" ] || return 1
    local IFS=','
    for pat in $SHARE_CLASSES; do
        [ -n "$pat" ] || continue
        # shellcheck disable=SC2254 # glob patterns in share_classes are intended
        case "$class" in $pat) return 0 ;; esac
    done
    return 1
}

marker_value() {
    awk -F= -v k="$2" '$1 == k { print $2; exit }' "$1" 2>/dev/null || true
}

share_start() { # share_start <address> <class>
    local addr="$1" class="$2" dnd caffeine tmp
    [ -n "$SHARE_CLASSES" ] || return 0
    [ -e "$SHARE_MARKER" ] && return 0
    share_matches "$class" || return 0
    [ -x "$CONTROLS" ] || return 0

    dnd="$("$CONTROLS" get dnd 2>/dev/null || echo off)"
    caffeine="$("$CONTROLS" get caffeine 2>/dev/null || echo off)"
    mkdir -p "$STATE"
    tmp="$(mktemp "$STATE/.eventd-share.XXXXXX")"
    printf 'addr=%s\ndnd=%s\ncaffeine=%s\n' "$addr" "$dnd" "$caffeine" >"$tmp"
    chmod 600 "$tmp"
    mv -f "$tmp" "$SHARE_MARKER"

    "$CONTROLS" dnd on >/dev/null 2>&1 || true
    "$CONTROLS" caffeine off >/dev/null 2>&1 || true
    note "Шаринг экрана: не беспокоить, кофеин снят"
}

share_stop() { # share_stop <address>
    local addr="$1" saved dnd caffeine
    [ -r "$SHARE_MARKER" ] || return 0
    saved="$(marker_value "$SHARE_MARKER" addr)"
    [ "$saved" = "$addr" ] || return 0
    dnd="$(marker_value "$SHARE_MARKER" dnd)"
    caffeine="$(marker_value "$SHARE_MARKER" caffeine)"
    rm -f "$SHARE_MARKER"
    [ -x "$CONTROLS" ] || return 0
    "$CONTROLS" dnd "${dnd:-off}" >/dev/null 2>&1 || true
    "$CONTROLS" caffeine "${caffeine:-off}" >/dev/null 2>&1 || true
    note "Шаринг экрана завершён: состояние возвращено"
}

run_hook() { # run_hook <name> <argument>
    local hook="$HOOKS/$1.sh"
    [ -x "$hook" ] || return 0
    "$hook" "$2" >/dev/null 2>&1 || true
}

keyboard_restore() { # keyboard_restore <class>
    [ -n "$1" ] && [ -x "$KEYBOARD_MEMORY" ] || return 0
    "$KEYBOARD_MEMORY" restore "$1" >/dev/null 2>&1 || true
}

keyboard_remember() { # keyboard_remember <layout>
    [ -n "$1" ] && [ -x "$KEYBOARD_MEMORY" ] || return 0
    "$KEYBOARD_MEMORY" remember-active "$1" >/dev/null 2>&1 || true
}

handle_event() {
    local line="$1" name data addr rest class
    case "$line" in
        *'>>'*) ;;
        *) return 0 ;;
    esac
    name="${line%%>>*}"
    data="${line#*>>}"

    case "$name" in
        openwindow)
            addr="${data%%,*}"
            rest="${data#*,}"
            rest="${rest#*,}"
            class="${rest%%,*}"
            apply_rule "$addr" "$class"
            share_start "$addr" "$class"
            ;;
        closewindow)
            addr="${data%%,*}"
            share_stop "$addr"
            ;;
        monitoradded) run_hook monitor-added "$data" ;;
        monitorremoved) run_hook monitor-removed "$data" ;;
        activewindow)
            class="${data%%,*}"
            keyboard_restore "$class"
            ;;
        activelayout)
            class="${data#*,}"
            keyboard_remember "$class"
            ;;
        fullscreen)
            addr="${data%%,*}"
            if [ "${data##*,}" = 1 ]; then
                run_hook fullscreen-on "$addr"
            else
                run_hook fullscreen-off "$addr"
            fi
            ;;
        *) : ;;
    esac
    return 0
}

run_socket() {
    [ -n "$SOCKET" ] || die "HYPRLAND_INSTANCE_SIGNATURE не задан"
    [ -S "$SOCKET" ] || die "нет сокета событий: $SOCKET"
    while :; do
        while IFS= read -r line; do
            handle_event "$line"
        done <"$SOCKET" || true
        sleep 1
    done
}

run_fake() {
    local file="$1"
    [ -r "$file" ] || die "нет файла событий: $file"
    while IFS= read -r line; do
        handle_event "$line"
    done <"$file"
}

status() {
    load_config
    local running=no
    if command -v pgrep >/dev/null 2>&1 && pgrep -f "eventd.sh run" >/dev/null 2>&1; then
        running=yes
    fi
    printf 'eventd: %s\n' "$running"
    printf 'socket: %s\n' "${SOCKET:-нет (вне Hyprland)}"
    printf 'правила: %s\n' "$([ -r "$RULES" ] && echo "$RULES" || echo 'нет')"
    printf 'шаринг: %s\n' "${SHARE_CLASSES:-выключен}"
    if [ -x "$KEYBOARD_MEMORY" ]; then
        printf 'раскладки: %s\n' "$("$KEYBOARD_MEMORY" status 2>/dev/null | head -n 2 | tr '\n' ' ')"
    fi
    if [ -r "$SHARE_MARKER" ]; then
        printf 'активный шаринг: %s\n' "$(marker_value "$SHARE_MARKER" addr)"
    fi
    printf 'хуки: %s\n' "$([ -d "$HOOKS" ] && echo "$HOOKS" || echo 'нет')"
}

main() {
    load_config
    case "${1:-}" in
        run)
            if [ "${2:-}" = --fake ]; then
                [ -n "${3:-}" ] || usage
                run_fake "$3"
            else
                run_socket
            fi
            ;;
        handle)
            [ -n "${2:-}" ] || usage
            handle_event "$2"
            ;;
        status) status ;;
        *) usage ;;
    esac
}

main "$@"
