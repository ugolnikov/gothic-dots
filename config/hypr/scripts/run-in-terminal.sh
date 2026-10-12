#!/usr/bin/env bash
# run-in-terminal.sh — открыть терминал (без аргументов) или выполнить в нём
# команду. Терминал выбирается в центре настроек и хранится в
# ~/.config/hypr/terminal.
#   run-in-terminal.sh                 → новый терминал (шелл)
#   run-in-terminal.sh nmtui           → терминал с командой nmtui
#   run-in-terminal.sh -e htop         → тоже (совместимость с rofi/.desktop)

set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
term="$(cat "$CONFIG/hypr/terminal" 2>/dev/null || echo foot)"

[ "${1:-}" = "-e" ] && shift

if [ "$#" -eq 0 ]; then
    case "$term" in
        foot) exec footclient ;;
        foot-raw) exec foot ;;
        kitty) exec kitty ;;
        alacritty) exec alacritty ;;
        wezterm) exec wezterm ;;
        *) exec "$term" ;;
    esac
fi

case "$term" in
    foot) exec footclient "$@" ;;
    foot-raw) exec foot "$@" ;;
    kitty) exec kitty "$@" ;;
    alacritty) exec alacritty -e "$@" ;;
    wezterm) exec wezterm start -- "$@" ;;
    *) exec "$term" "$@" ;;
esac
