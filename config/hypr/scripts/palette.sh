#!/usr/bin/env bash
# palette.sh — единый модуль палитры рабочего стола.
#   palette.sh status            — показать текущий режим
#   palette.sh set <mode>        — задать режим (dark|light|dynamic), применить, перезагрузить
#   palette.sh toggle            — переключить dark ⇄ light
#   palette.sh apply [image]     — применить текущий режим (image — только для dynamic)
#   palette.sh clear             — очистить генерацию и вернуться в dark
#
# Модуль владеет набором генерируемых файлов (по одному на потребителя цвета),
# их предсозданием, перезагрузкой потребителей и режимом. Режим хранится одним
# маркером ~/.config/hypr/palette-mode; пока его нет, один раз читаются старые
# маркеры: light-theme → light, dynamic-theme → dynamic, иначе dark.
#
# dark = нет сгенерированного содержимого: файлы остаются, но пустые, и
# применяется фиксированная готик-палитра.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

# Единственное место, где перечислены генерируемые файлы — по одному на
# потребителя цвета. Тот же список драйвит предсоздание и очистку.
TARGETS=(
    "$CONFIG/hypr/conf.d/colors.dynamic.conf"
    "$CONFIG/waybar/colors.dynamic.css"
    "$CONFIG/rofi/colors.dynamic.rasi"
    "$CONFIG/kitty/colors.dynamic.conf"
    "$CONFIG/swaync/colors.dynamic.css"
)

MODE_FILE="$CONFIG/hypr/palette-mode"
LEGACY_LIGHT="$CONFIG/hypr/light-theme"
LEGACY_DYNAMIC="$CONFIG/hypr/dynamic-theme"

# Сохранённые обои — источник палитры по умолчанию для dynamic.
WALLPAPER="$CONFIG/hypr/wallpaper.png"

usage() {
    echo "usage: palette.sh status|set <dark|light|dynamic>|toggle|apply [image]|clear" >&2
    exit 2
}

die() {
    echo "palette.sh: $*" >&2
    exit 2
}

# Перезагрузка потребителей цвета. Не установленный или не запущенный
# потребитель — не ошибка: сбой глушится.
reload() {
    hyprctl reload >/dev/null 2>&1 || true
    pkill -SIGUSR2 -x waybar 2>/dev/null || true
    swaync-client --reload-css >/dev/null 2>&1 || true
}

# current_mode — единственное значение режима. Старые маркеры читаются, пока
# palette-mode ещё не создан (миграция существующей сессии).
current_mode() {
    if [ -r "$MODE_FILE" ]; then
        cat "$MODE_FILE"
    elif [ -e "$LEGACY_LIGHT" ]; then
        echo light
    elif [ -e "$LEGACY_DYNAMIC" ]; then
        echo dynamic
    else
        echo dark
    fi
}

# clear_targets — режим dark: файлы на месте, но пустые, чтобы фиксированная
# готик-палитра применилась, а импорт не падал на отсутствующем include.
clear_targets() {
    local f
    for f in "${TARGETS[@]}"; do
        mkdir -p "$(dirname "$f")"
        : >"$f"
    done
}

# ensure_targets — файлы на месте, чтобы импорт не падал на отсутствующем
# include, даже если генератор ничего не записал.
ensure_targets() {
    local f
    for f in "${TARGETS[@]}"; do
        mkdir -p "$(dirname "$f")"
        [ -e "$f" ] || : >"$f"
    done
}

# generate_palette <image> — режим dynamic: палитра из обоев. Генерацию
# делегируем внешнему генератору (wallust) с его конфигом шаблонов; при сбое
# пробуем сохранённые обои, но не валим вызывающего — targets остаются
# пригодными для импорта.
generate_palette() {
    local image="$1"
    if command -v wallust >/dev/null 2>&1; then
        wallust run "$image" || wallust run "$WALLPAPER" || true
    fi
    ensure_targets
}

# materialise_mode <mode> [image] — наполнить targets под режим. Содержимое
# light добавляет отдельное изменение модуля; пока оно отсутствует, режим
# отклоняется явно, а не молча ничего не делает.
materialise_mode() {
    case "$1" in
        dark) clear_targets ;;
        dynamic) generate_palette "${2:-$WALLPAPER}" ;;
        light) die "light mode is not implemented yet" ;;
    esac
}

persist_mode() {
    mkdir -p "$(dirname "$MODE_FILE")"
    printf '%s\n' "$1" >"$MODE_FILE"
}

set_mode() { # set_mode <dark|light|dynamic> [image]
    case "${1:-}" in
        dark | light | dynamic) ;;
        *) usage ;;
    esac
    materialise_mode "$1" "${2:-}"
    persist_mode "$1"
    reload
}

# apply_mode [image] — применить текущий режим, не меняя его.
apply_mode() {
    materialise_mode "$(current_mode)" "${1:-}"
    reload
}

toggle_mode() {
    if [ "$(current_mode)" = light ]; then
        set_mode dark
    else
        set_mode light
    fi
}

main() {
    case "${1:-}" in
        status) current_mode ;;
        set) set_mode "${2:-}" "${3:-}" ;;
        toggle) toggle_mode ;;
        apply) apply_mode "${2:-}" ;;
        clear) set_mode dark ;;
        *) usage ;;
    esac
}

main "$@"
