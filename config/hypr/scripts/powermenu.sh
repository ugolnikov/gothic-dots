#!/usr/bin/env bash
# powermenu.sh — меню питания в rofi.

set -euo pipefail

opts="󰌾  Блокировка\n󰍃  Выход\n󰒲  Сон\n󰜉  Перезагрузка\n󰐥  Выключение"

chosen="$(printf '%b' "$opts" |
    rofi -dmenu -i -p "Питание" \
        -theme ~/.config/rofi/powermenu.rasi)" || exit 0

case "$chosen" in
    *Блокировка) hyprlock ;;
    *Выход) hyprctl dispatch exit ;;
    *Сон) systemctl suspend ;;
    *Перезагрузка) systemctl reboot ;;
    *Выключение) systemctl poweroff ;;
    *) exit 0 ;;
esac
