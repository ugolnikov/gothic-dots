#!/usr/bin/env bash
# keybinds.sh — шпаргалка по клавишам в rofi.
# Клавиша: SUPER + /
# Источник — config/hypr/keybinds.tsv (тот же, что рендерит gen-keybinds.sh в
# README.md). Показ только для чтения: выбор строки отбрасывается.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
TSV="$CONFIG/hypr/keybinds.tsv"
THEME="$CONFIG/rofi/settings.rasi"

[ -f "$TSV" ] || {
    notify-send "Клавиши" "нет $TSV" 2>/dev/null || true
    echo "keybinds: missing $TSV" >&2
    exit 0
}

# Строки «key <TAB> action», выровненные по самой длинной клавише. Бэктики из
# таблицы (разметка README) снимаем, строки-комментарии пропускаем.
awk -F'\t' '
    /^#/ || NF < 2 { next }
    {
        key = $1
        gsub(/`/, "", key)
        keys[++n] = key
        acts[n] = $2
        if (length(key) > max) max = length(key)
    }
    END {
        for (i = 1; i <= n; i++)
            printf "%-*s — %s\n", max, keys[i], acts[i]
    }
' "$TSV" | rofi -dmenu -i -p "Клавиши" -theme "$THEME" >/dev/null || true
