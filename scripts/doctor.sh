#!/usr/bin/env bash
# doctor.sh — проверка здоровья райса: команды, симлинки, шрифты, конфиг Hyprland.
#   scripts/doctor.sh           проверить
#   scripts/doctor.sh --fix     починить безопасное и проверить
# Выходит с кодом 1, если не хватает чего-то обязательного.
set -uo pipefail

FIX=0
while [ $# -gt 0 ]; do
    case "$1" in
        --fix) FIX=1 ;;
        -h | --help)
            sed -n '2,5p' "$0"
            exit 0
            ;;
        *)
            echo "doctor.sh: неизвестный аргумент: $1" >&2
            echo "использование: doctor.sh [--fix]" >&2
            exit 2
            ;;
    esac
    shift
done

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
FIXED=0
fixed() {
    printf '  %b✚%b %s\n' "$GRN" "$NC" "$*"
    FIXED=$((FIXED + 1))
}

# is_ours <path> — истина, когда путь это симлинк внутрь репозитория.
is_ours() {
    [ -L "$1" ] || return 1
    local t
    t="$(readlink -f "$1" 2>/dev/null || true)"
    case "$t" in "$ROOT"/*) return 0 ;; *) return 1 ;; esac
}

# --fix: чиним только безопасное — то, что не затрёт пользовательские данные.
# Отсутствующие ссылки восстанавливаем, чужие файлы не трогаем; остальное
# (hooksPath, кэши, локальный конфиг мониторов) правим по образцу install.sh.
if [ "$FIX" = 1 ]; then
    sec "Починка"

    while IFS=$'\t' read -r src dst; do
        [ -n "$dst" ] || continue
        # Существующее не трогаем: чужой файл останется и попадёт в отчёт ниже.
        [ -e "$dst" ] && continue
        mkdir -p "$(dirname "$dst")"
        ln -sfnT "$src" "$dst"
        fixed "ссылка восстановлена: $dst"
    done < <("$ROOT/scripts/link-plan.sh" 2>/dev/null || true)

    if [ -d "$ROOT/.git" ] && command -v git >/dev/null 2>&1; then
        if [ "$(git -C "$ROOT" config core.hooksPath 2>/dev/null || true)" != ".githooks" ]; then
            git -C "$ROOT" config core.hooksPath .githooks
            fixed "git: core.hooksPath=.githooks"
        fi
    fi

    # Кэши пересобираем не фатально: их отсутствие не портит райс.
    if command -v bat >/dev/null 2>&1; then
        if bat cache --build >/dev/null 2>&1; then fixed "bat: кэш тем пересобран"; else warn "bat: не удалось пересобрать кэш тем"; fi
    fi
    if command -v fc-cache >/dev/null 2>&1; then
        if fc-cache -f >/dev/null 2>&1; then fixed "fc-cache: кэш шрифтов обновлён"; else warn "fc-cache: не удалось обновить кэш шрифтов"; fi
    fi

    # Локальный оверрайд мониторов сеем копией из примера, как install.sh.
    _hypr_local="$HOME/.config/hypr/conf.d/monitors.local.conf"
    if [ ! -e "$_hypr_local" ] && [ -e "$_hypr_local.EXAMPLE" ] && is_ours "$HOME/.config/hypr"; then
        cp "$_hypr_local.EXAMPLE" "$_hypr_local"
        fixed "hypr: monitors.local.conf создан из EXAMPLE"
    fi
fi

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
# Проверяем ровно те назначения, что перечисляет план ссылок, а не отдельный
# список, который отстаёт от реального набора. Формат плана: src<TAB>dst.
while IFS=$'\t' read -r _src dst; do
    [ -n "$dst" ] || continue
    # readlink -f сам возвращает путь несуществующего файла, поэтому
    # отсутствие проверяем отдельно, иначе «нет ссылки» выглядит как «чужая».
    if [ ! -e "$dst" ]; then
        bad "$dst — отсутствует"
        continue
    fi
    t="$(readlink -f "$dst" 2>/dev/null || true)"
    case "$t" in
        "$ROOT"/*) ok "$dst" ;;
        "") bad "$dst — отсутствует" ;;
        *) warn "$dst → $t (не из репозитория)" ;;
    esac
done < <("$ROOT/scripts/link-plan.sh" 2>/dev/null || true)

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
if [ "$FIX" = 1 ]; then
    if [ "$FIXED" -gt 0 ]; then
        ok "починено: $FIXED"
    else
        ok "чинить нечего"
    fi
fi
if [ "$missing" -gt 0 ]; then
    warn "не хватает $missing обязательных команд"
    exit 1
fi
ok "обязательные компоненты на месте"
