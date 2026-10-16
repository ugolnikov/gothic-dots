#!/usr/bin/env bash
# theme.sh — поставить обои и перекрасить рабочий стол под них.
#   theme.sh [путь-к-обоям]
#
# Ставит обои (awww/mpvpaper) и сохраняет их копию для локскрина. Палитру
# применяет модуль palette.sh: он владеет режимом (dark/light/dynamic),
# генерацией из обоев, предсозданием файлов и перезагрузкой потребителей цвета.
# Запускается при логине (autostart.conf), так что тема сама встаёт из обоев.

set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

# Обои: явный аргумент, иначе — сохранённые, или случайные из коллекции, если
# включён маркер ~/.config/hypr/random-wallpaper.
WALL="${1:-}"
if [ -z "$WALL" ]; then
    WALL="$CONFIG/hypr/wallpaper.png"
    if [ -e "$CONFIG/hypr/random-wallpaper" ]; then
        _pick="$(find "$HOME/Wallpapers" "$HOME/Pictures" "$CONFIG/hypr/wallpapers" \
            -maxdepth 2 -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
            2>/dev/null | shuf -n1)"
        [ -n "$_pick" ] && WALL="$_pick"
    fi
fi

# 1. Обои (статика, GIF или видео).
"$CONFIG/hypr/scripts/wallpaper.sh" "$WALL"

# 2. Сохранить текущие обои для локскрина (файл gitignored).
if [ "$(readlink -f "$WALL")" != "$(readlink -f "$CONFIG/hypr/wallpaper.png" 2>/dev/null || true)" ]; then
    cp -f "$WALL" "$CONFIG/hypr/wallpaper.png" 2>/dev/null || true
fi

# 3. Палитра: режим, генерацию, предсоздание файлов и перезагрузку потребителей
#    целиком владеет модуль palette.sh. Передаём обои — режим dynamic сгенерирует
#    палитру из них; в dark/light аргумент игнорируется.
"$CONFIG/hypr/scripts/palette.sh" apply "$WALL"

notify-send "Тема" "Палитра обновлена из обоев" 2>/dev/null || true
