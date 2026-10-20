#!/usr/bin/env bash
# keyboard-memory.sh — последняя раскладка на класс окна.
#   keyboard-memory.sh restore <class>        вернуть раскладку классу
#   keyboard-memory.sh remember-active <layout>
#                                             запомнить раскладку активного окна
#   keyboard-memory.sh list                   таблица class<TAB>layout
#   keyboard-memory.sh status                 файл и число записей
#   keyboard-memory.sh clear                  забыть всё
#
# Состояние — один файл ~/.config/hypr/keyboard-memory.tsv; им владеет только
# этот модуль. eventd зовёт restore на activewindow и remember-active на
# activelayout, поэтому память не зависит от того, кто переключил раскладку.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$CONFIG/hypr"
MEMORY="${KEYBOARD_MEMORY_FILE:-$STATE/keyboard-memory.tsv}"
HYPRCTL="${KEYBOARD_MEMORY_HYPRCTL:-hyprctl}"

usage() {
    cat >&2 <<'EOF'
usage: keyboard-memory.sh restore <class>
       keyboard-memory.sh remember-active <layout>
       keyboard-memory.sh list
       keyboard-memory.sh status
       keyboard-memory.sh clear
EOF
    exit 2
}

die() {
    echo "keyboard-memory.sh: $*" >&2
    exit 2
}

# active_class — класс активного окна; пусто, если окна нет.
active_class() {
    "$HYPRCTL" activewindow -j 2>/dev/null |
        jq -r '.class // empty' 2>/dev/null || true
}

# layout_for <class> — сохранённая раскладка или пустая строка.
layout_for() {
    local class="$1" saved_class saved_layout
    [ -r "$MEMORY" ] || return 0
    while IFS=$'\t' read -r saved_class saved_layout; do
        [ -n "$saved_class" ] || continue
        case "$saved_class" in \#*) continue ;; esac
        if [ "$saved_class" = "$class" ]; then
            printf '%s\n' "$saved_layout"
            return 0
        fi
    done <"$MEMORY"
}

# resolve <layout> — "keyboard<TAB>index" для главной клавиатуры, иначе первой.
resolve_layout() {
    local layout="$1"
    "$HYPRCTL" devices -j 2>/dev/null | jq -r --arg want "$layout" '
        (.keyboards // []) as $keyboards
        | (($keyboards | map(select(.main == true)) | .[0]) // $keyboards[0]) as $kb
        | ($kb.layouts // []) | to_entries[]
        | select(.value == $want)
        | "\($kb.name)\t\(.key)"
    ' 2>/dev/null | head -n 1
}

# remember <class> <layout> — атомарно заменить строку класса.
remember() {
    local class="$1" layout="$2" tmp saved_class saved_layout found=0
    [ -n "$class" ] && [ -n "$layout" ] || return 0
    case "$class$layout" in
        *$'\t'* | *$'\n'*) return 0 ;;
    esac

    mkdir -p "$STATE"
    tmp="$(mktemp "$STATE/.keyboard-memory.XXXXXX")"
    if [ -r "$MEMORY" ]; then
        while IFS=$'\t' read -r saved_class saved_layout; do
            [ -n "$saved_class" ] || continue
            case "$saved_class" in
                \#*)
                    printf '%s\t%s\n' "$saved_class" "$saved_layout"
                    continue
                    ;;
            esac
            if [ "$saved_class" = "$class" ]; then
                printf '%s\t%s\n' "$class" "$layout"
                found=1
            else
                printf '%s\t%s\n' "$saved_class" "$saved_layout"
            fi
        done <"$MEMORY" >"$tmp"
    fi
    [ "$found" = 1 ] || printf '%s\t%s\n' "$class" "$layout" >>"$tmp"
    chmod 600 "$tmp"
    mv -f "$tmp" "$MEMORY"
}

restore() {
    local class="$1" layout line keyboard index
    layout="$(layout_for "$class")"
    [ -n "$layout" ] || return 0
    line="$(resolve_layout "$layout")"
    [ -n "$line" ] || return 0
    keyboard="${line%%$'\t'*}"
    index="${line#*$'\t'}"
    [ -n "$keyboard" ] && [ -n "$index" ] || return 0
    "$HYPRCTL" switchxkblayout "$keyboard" "$index" >/dev/null 2>&1 || true
}

remember_active() {
    local layout="$1" class
    [ -n "$layout" ] || return 0
    class="$(active_class)"
    [ -n "$class" ] || return 0
    remember "$class" "$layout"
}

status() {
    local count=0
    if [ -r "$MEMORY" ]; then
        count="$(grep -vc '^#' "$MEMORY" 2>/dev/null || true)"
    fi
    printf 'память раскладок: %s\n' "$MEMORY"
    printf 'записей: %s\n' "${count:-0}"
    printf 'активное окно: %s\n' "$(active_class)"
}

main() {
    case "${1:-}" in
        restore)
            [ -n "${2:-}" ] || usage
            restore "$2"
            ;;
        remember-active)
            [ -n "${2:-}" ] || usage
            remember_active "$2"
            ;;
        list)
            [ -r "$MEMORY" ] && cat "$MEMORY"
            ;;
        status) status ;;
        clear) rm -f "$MEMORY" ;;
        *) usage ;;
    esac
}

main "$@"
