#!/usr/bin/env bash
# theme.sh — поставить обои и перекрасить рабочий стол под них.
#   theme.sh [путь-к-обоям]
#
# Делает три вещи: ставит обои (swww/mpvpaper), вытаскивает палитру из картинки
# через wallust (файлы colors.dynamic.*), перезагружает потребителей цвета.
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

# 3. Палитра из обоев — ТОЛЬКО если включено маркером. По умолчанию выключено:
#    рабочий стол использует фиксированную готик-палитру (conf.d/colors.conf).
#    Включить генерацию из обоев:  touch ~/.config/hypr/dynamic-theme
#    Светлая тема (light-theme) приоритетнее: она пишет те же файлы, поэтому
#    при ней wallust не запускаем.
if [ -e "$CONFIG/hypr/dynamic-theme" ] && [ ! -e "$CONFIG/hypr/light-theme" ] &&
    command -v wallust >/dev/null 2>&1; then
    wallust run "$WALL" || wallust run "$CONFIG/hypr/wallpaper.png" || true
fi

# Файлы для импорта должны существовать, иначе rofi ругается на отсутствующий
# include до первого успешного запуска wallust.
for f in \
    "$CONFIG/hypr/conf.d/colors.dynamic.conf" \
    "$CONFIG/waybar/colors.dynamic.css" \
    "$CONFIG/rofi/colors.dynamic.rasi" \
    "$CONFIG/swaync/colors.dynamic.css"; do
    [ -e "$f" ] || : >"$f"
done

# 4. Перезагрузить потребителей цвета.
hyprctl reload >/dev/null 2>&1 || true
pkill -SIGUSR2 -x waybar 2>/dev/null || true       # Waybar перечитывает CSS на SIGUSR2
swaync-client --reload-css >/dev/null 2>&1 || true # swaync, если используется
notify-send "Тема" "Палитра обновлена из обоев" 2>/dev/null || true
