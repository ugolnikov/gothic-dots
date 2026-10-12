#!/usr/bin/env bash
# screenshot.sh — скриншоты.
#   screenshot.sh full     весь экран
#   screenshot.sh region   выделенная область
#   screenshot.sh window   активное окно
# Снимок кладётся в ~/Pictures/Screenshots, копируется в буфер и показывается
# уведомлением.

set -euo pipefail

DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$DIR"
file="$DIR/$(date +%Y-%m-%d_%H-%M-%S).png"

case "${1:-region}" in
    full)
        grim "$file"
        ;;
    region)
        geom="$(slurp)" || exit 0
        grim -g "$geom" "$file"
        ;;
    window)
        geom="$(hyprctl activewindow -j \
            | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
        grim -g "$geom" "$file"
        ;;
    *)
        echo "usage: screenshot.sh [full|region|window]" >&2
        exit 1
        ;;
esac

wl-copy <"$file"
notify-send -i "$file" "Скриншот" "$(basename "$file")"
