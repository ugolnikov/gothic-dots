#!/usr/bin/env bash
# quick.sh — быстрые переключатели сессии в rofi (SUPER + Shift + C).
#   quick.sh          открыть панель
#   quick.sh --list   напечатать строки панели, не открывая rofi
#
# Панель — только вид: состояние и действия принадлежат controls.sh, поэтому
# панель не читает маркеры сама, а спрашивает `get` и передаёт выбор модулю.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
CTL="$CONFIG/hypr/scripts/controls.sh"
ROFI_THEME="$CONFIG/rofi/settings.rasi"
SCRIPTS="$CONFIG/hypr/scripts"

mark() {
    if [ "$("$CTL" get "$1")" = on ]; then
        printf '●'
    else
        printf '○'
    fi
}

panel_rows() {
    local rec
    rec="$("$CTL" get recording)"
    printf '%s\n' \
        "$(mark dnd) Не беспокоить" \
        "$(mark night) Ночной свет" \
        "$(mark caffeine) Кофеин — не гасить экран"
    if [ "$rec" = on ]; then
        printf '%s\n' "$(mark recording) Остановить запись"
    else
        printf '%s\n' \
            "Записать экран (полный, со звуком)" \
            "Записать область (со звуком)"
    fi
    printf '%s\n' "Настройки" "Питание"
}

choose() {
    local choice
    command -v rofi >/dev/null 2>&1 || {
        echo "quick.sh: rofi не установлен" >&2
        exit 1
    }
    choice="$(panel_rows | rofi -dmenu -i -p "Быстро" -theme "$ROFI_THEME")" || exit 0
    [ -n "$choice" ] || exit 0
    case "$choice" in
        *"Не беспокоить") "$CTL" dnd toggle ;;
        *"Ночной свет") "$CTL" night toggle ;;
        *"Кофеин"*) "$CTL" caffeine toggle ;;
        *"Остановить запись") "$CTL" record stop ;;
        *"Записать экран"*) "$CTL" record start full audio ;;
        *"Записать область"*) "$CTL" record start region audio ;;
        "Настройки") exec "$SCRIPTS/settings.sh" ;;
        "Питание") exec "$SCRIPTS/powermenu.sh" ;;
        *) exit 0 ;;
    esac
}

case "${1:-}" in
    --list) panel_rows ;;
    "") choose ;;
    *)
        echo "usage: quick.sh [--list]" >&2
        exit 2
        ;;
esac
