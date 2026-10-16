#!/usr/bin/env bash
# theme-mode.sh — быстрое переключение готической палитры: тёмная ⇄ светлая.
#   theme-mode.sh dark | light | toggle | status
#
# Тонкая обёртка над модулем палитры (palette.sh): содержимое *.dynamic.*,
# перезагрузка потребителей и режим живут там. Этот вход сохраняет прежний CLI
# для кеймбайнда (SUPER+SHIFT+T) и центра настроек (settings.sh).
set -euo pipefail

# Модуль — сосед по установочному каталогу ($CONFIG/hypr/scripts), поэтому
# резолвим его относительно самого скрипта: так вход работает и из чекаута, и
# из установленной конфигурации (симлинка), не завися от пути установки.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PALETTE="$HERE/palette.sh"

# status — режим в терминах этого входа: light либо dark. У модуля есть третий
# режим (dynamic — палитра из обоев); для развилки светлая/тёмная он считается
# тёмной готикой.
status() {
    if [ "$("$PALETTE" status)" = light ]; then echo light; else echo dark; fi
}

case "${1:-toggle}" in
    dark | light) "$PALETTE" set "$1" ;;
    toggle) "$PALETTE" toggle ;;
    status) status ;;
    *)
        echo "usage: theme-mode.sh [dark|light|toggle|status]" >&2
        exit 1
        ;;
esac

notify-send "Тема" "$([ "$(status)" = light ] && echo 'светлая' || echo 'готика (тёмная)')" 2>/dev/null || true
