#!/usr/bin/env bash
# notifications.sh — запустить выбранный демон уведомлений.
# Выбор хранится в ~/.config/hypr/notifications (пишет центр настроек).
# Останавливает оба демона и поднимает только нужный, чтобы не было конфликта.

set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
want="$(cat "$CONFIG/hypr/notifications" 2>/dev/null || echo mako)"

pkill -x swaync 2>/dev/null || true
pkill -x mako 2>/dev/null || true
sleep 0.2

case "$want" in
    swaync)
        exec swaync
        ;;
    mako)
        f="$HOME/.cache/wallust/mako"
        if [ -f "$f" ]; then exec mako -c "$f"; else exec mako; fi
        ;;
    *)
        exec mako
        ;;
esac
