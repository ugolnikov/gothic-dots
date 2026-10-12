#!/usr/bin/env bash
# doctor.sh — проверка здоровья райса: команды, симлинки, шрифты, конфиг Hyprland.
#   scripts/doctor.sh
# Выходит с кодом 1, если не хватает чего-то обязательного.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GRN='\033[0;32m'
YEL='\033[0;33m'
RED='\033[0;31m'
DIM='\033[2m'
NC='\033[0m'
ok() { printf '  %b✔%b %s\n' "$GRN" "$NC" "$*"; }
warn() { printf '  %b•%b %s\n' "$YEL" "$NC" "$*"; }
bad() { printf '  %b✘%b %s\n' "$RED" "$NC" "$*"; }
sec() { printf '\n%b%s%b\n' "$DIM" "$*" "$NC"; }

missing=0

sec "Команды"
for c in hyprland hyprctl hypridle hyprlock awww waybar foot footclient \
    grim slurp wl-copy wl-paste cliphist jq brightnessctl playerctl notify-send; do
    command -v "$c" >/dev/null 2>&1 || {
        bad "нет: $c"
        missing=$((missing + 1))
    }
done
[ "$missing" -eq 0 ] && ok "все базовые команды на месте"

sec "Опционально"
for c in tofi tofi-drun wallust magick mpvpaper swappy wl-clip-persist hyprpicker starship; do
    if command -v "$c" >/dev/null 2>&1; then ok "$c"; else warn "нет: $c"; fi
done

sec "Симлинки"
for p in "$HOME/.gitconfig" "$HOME/.tmux.conf" "$HOME/.vimrc" "$HOME/.bashrc" \
    "$HOME/.profile" "$HOME/.editorconfig" "$HOME/.config/starship.toml" \
    "$HOME/.local/bin/please" "$HOME/.config/hypr" "$HOME/.config/fish" \
    "$HOME/.config/waybar"; do
    t="$(readlink -f "$p" 2>/dev/null || true)"
    case "$t" in
        "$ROOT"/*) ok "$p" ;;
        "") bad "$p — отсутствует" ;;
        *) warn "$p → $t (не из репозитория)" ;;
    esac
done

if command -v git >/dev/null 2>&1 && [ -d "$ROOT/.git" ]; then
    sec "Git"
    hooks="$(git -C "$ROOT" config core.hooksPath 2>/dev/null || true)"
    if [ "$hooks" = ".githooks" ]; then ok "хук включён (core.hooksPath=.githooks)"; else warn "хук не включён — запусти install.sh"; fi
fi

sec "Шрифты"
for fam in "Cormorant Garamond" "Cinzel" "FreeSerif" "JetBrainsMono Nerd Font"; do
    if fc-match -q "$fam" 2>/dev/null | grep -qi "$fam"; then ok "$fam"; else warn "$fam → $(fc-match "$fam" 2>/dev/null)"; fi
done

sec "Hyprland"
if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    errs="$(hyprctl configerrors 2>/dev/null || true)"
    if [ -z "$errs" ]; then ok "конфиг без ошибок"; else
        bad "hyprctl configerrors:"
        printf '%s\n' "$errs" | sed 's/^/      /'
    fi
else
    warn "Hyprland не запущен — пропускаю"
fi

printf '\n'
if [ "$missing" -gt 0 ]; then
    warn "не хватает $missing обязательных команд"
    exit 1
fi
ok "обязательные компоненты на месте"
