#!/usr/bin/env bash
# filemanager.sh — открыть файловый менеджер (SUPER + E).
# GUI, если он установлен (nautilus/thunar/nemo/pcmanfm), иначе TUI yazi в
# терминале, выбранном в центре настроек. Так бинд работает и на минимальной
# установке, где тяжёлого GTK-файлменеджера нет вовсе.

set -euo pipefail

for fm in nautilus thunar nemo pcmanfm; do
    if command -v "$fm" >/dev/null 2>&1; then
        exec "$fm" "$@"
    fi
done

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
exec "$CONFIG/hypr/scripts/run-in-terminal.sh" yazi
