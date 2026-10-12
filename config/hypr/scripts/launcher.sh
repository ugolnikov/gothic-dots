#!/usr/bin/env bash
# launcher.sh — лаунчер приложений: tofi, с откатом на rofi.
# Клавиши: SUPER + D, SUPER + Space.
# Если включена тема из обоев, берётся сгенерированный конфиг tofi
# (~/.cache/wallust/tofi) через `tofi -c`; иначе — статичный готик.

set -euo pipefail

cfg="${XDG_CACHE_HOME:-$HOME/.cache}/wallust/tofi"

if command -v tofi-drun >/dev/null 2>&1; then
    if [ -f "$cfg" ]; then
        exec tofi-drun -c "$cfg"
    fi
    exec tofi-drun
fi

exec rofi -show drun
