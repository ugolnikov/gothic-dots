#!/usr/bin/env bash
# clipboard.sh — история буфера обмена (cliphist) в rofi.
#   Клавиша: SUPER + Shift + V
# Выбор строки декодируется cliphist и кладётся в буфер (wl-copy).
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

if ! command -v cliphist >/dev/null 2>&1; then
    notify-send "Буфер обмена" "нужен пакет cliphist" 2>/dev/null || true
    exit 0
fi

sel="$(cliphist list | rofi -dmenu -i -p "Буфер" -theme "$CONFIG/rofi/settings.rasi")" || exit 0
[ -n "$sel" ] || exit 0

printf '%s' "$sel" | cliphist decode | wl-copy
