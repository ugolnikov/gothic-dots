#!/usr/bin/env bash
# wallpaper.sh — поставить обои: статика, GIF или видео.
#   wallpaper.sh [путь]
#
#   .png/.jpg/... -> swww (плавные переходы)
#   .gif          -> swww (анимированный GIF)
#   .mp4/.webm    -> mpvpaper (видео-обои, нужен пакет mpvpaper)
#
# Без аргумента берёт ~/.config/hypr/wallpaper.png и, если его нет, генерирует
# градиент (нужен imagemagick).

set -euo pipefail

WALL="${1:-$HOME/.config/hypr/wallpaper.png}"

if [ ! -f "$WALL" ]; then
    if command -v magick >/dev/null 2>&1; then
        magick -size 2560x1440 gradient:'#17171a-#0a0a0b' "$WALL"
    elif command -v convert >/dev/null 2>&1; then
        convert -size 2560x1440 gradient:'#17171a-#0a0a0b' "$WALL"
    else
        echo "wallpaper.sh: нет картинки и нет imagemagick для генерации" >&2
        exit 1
    fi
fi

ext="$(printf '%s' "${WALL##*.}" | tr '[:upper:]' '[:lower:]')"

_set_static_or_gif() {
    if ! pgrep -x swww-daemon >/dev/null 2>&1; then
        swww-daemon --format xrgb >/dev/null 2>&1 &
        sleep 0.4
    fi
    swww img "$WALL" \
        --transition-type any \
        --transition-duration 1.2 \
        --transition-fps 60 \
        --transition-bezier .43,1.19,1,.4
}

case "$ext" in
    mp4 | webm | mkv | mov)
        if ! command -v mpvpaper >/dev/null 2>&1; then
            echo "wallpaper.sh: для видео нужен mpvpaper" >&2
            exit 1
        fi
        pkill -x swww-daemon 2>/dev/null || true
        pkill -x mpvpaper 2>/dev/null || true
        mpvpaper -o "no-audio --loop-file=inf --panscan=1.0" '*' "$WALL" >/dev/null 2>&1 &
        ;;
    *)
        pkill -x mpvpaper 2>/dev/null || true
        _set_static_or_gif
        ;;
esac
