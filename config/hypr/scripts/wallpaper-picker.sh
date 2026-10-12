#!/usr/bin/env bash
# wallpaper-picker.sh — выбрать обои в rofi с превью.
#   • сканирует ~/Pictures (2 уровня), ~/Wallpapers, ~/.config/hypr/wallpapers
#   • рисует сетку миниатюр (кэш в ~/.cache/wallpaper-picker/thumbs)
#   • по выбору вызывает theme.sh: обои + палитра из них (wallust)
#
# Фильтр: переменная PICKER_FILTER = image | video | all (по умолчанию all).
# Клавиша по умолчанию: SUPER + W.

set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-picker"
THEME="$CONFIG/rofi/wallpaper.rasi"
THUMBS="$CACHE/thumbs"
mkdir -p "$THUMBS"

DIRS=(
    "$HOME/Pictures"
    "$HOME/Wallpapers"
    "$CONFIG/hypr/wallpapers"
)

case "${PICKER_FILTER:-all}" in
    video)
        EXTS=(-iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov')
        ;;
    image)
        EXTS=(-iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp')
        ;;
    *)
        EXTS=(-iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' \
            -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.mp4' -o -iname '*.webm')
        ;;
esac

mapfile -t files < <(
    find "${DIRS[@]}" -maxdepth 2 -type f \( "${EXTS[@]}" \) 2>/dev/null | sort -u
)

if [ "${#files[@]}" -eq 0 ]; then
    notify-send "Обои" "Не нашёл подходящих файлов в ~/Pictures / ~/Wallpapers" 2>/dev/null || true
    echo "wallpaper-picker: нет файлов" >&2
    exit 0
fi

# Выбор картинки. Каждая строка — путь, к ней приклеен значок-миниатюра
# (rofi-разметка: текст \0icon\x1fпуть).
selection="$({
    for f in "${files[@]}"; do
        key="$(printf '%s' "$f" | md5sum | cut -d' ' -f1)"
        thumb="$THUMBS/$key.png"
        if [ ! -f "$thumb" ] || [ "$f" -nt "$thumb" ]; then
            if command -v magick >/dev/null 2>&1; then
                magick "${f}[0]" -thumbnail '320x180^' -gravity center -extent 320x180 "$thumb" 2>/dev/null || continue
            elif command -v convert >/dev/null 2>&1; then
                convert "${f}[0]" -thumbnail '320x180^' -gravity center -extent 320x180 "$thumb" 2>/dev/null || continue
            else
                notify-send "Обои" "Нужен imagemagick для превью" 2>/dev/null || true
                exit 1
            fi
        fi
        display="${f/#$HOME/~}"
        printf '%s\0icon\x1f%s\n' "$display" "$thumb"
    done
} | rofi -dmenu -i -p "Обои" -show-icons -theme "$THEME")" || exit 0

[ -n "$selection" ] || exit 0

wall="${selection/#\~/$HOME}"
"$CONFIG/hypr/scripts/theme.sh" "$wall"
