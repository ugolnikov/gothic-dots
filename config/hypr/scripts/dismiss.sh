#!/usr/bin/env bash
# dismiss.sh — закрыть все уведомления у текущего демона (mako или swaync).
# Демон выбирается в центре настроек и хранится в ~/.config/hypr/notifications.
# Клавиша: SUPER + N. Раньше здесь был жёсткий makoctl, который ломался
# при переключении уведомлений на swaync.

set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
want="$(cat "$CONFIG/hypr/notifications" 2>/dev/null || echo mako)"

dismiss_mako() {
    command -v makoctl >/dev/null 2>&1 && makoctl dismiss -a
}
dismiss_swaync() {
    command -v swaync-client >/dev/null 2>&1 && swaync-client --close-all
}

case "$want" in
    swaync) dismiss_swaync || dismiss_mako ;;
    *) dismiss_mako || dismiss_swaync ;;
esac

exit 0
