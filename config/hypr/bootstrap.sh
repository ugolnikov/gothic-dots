#!/usr/bin/env bash
# bootstrap.sh — поставить пакеты райса на Arch / CachyOS:
# официальные из packages.txt и AUR из aur.packages.txt (через paru или yay).
#
# Запуск из любого места:  config/hypr/bootstrap.sh
# Затем разложить конфиги:  cd ~/dotfiles && ./install.sh --no-packages

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# pkg_list <file> — package names; full-line and inline (# ...) comments stripped
# so a trailing comment can never be passed to pacman as part of the name.
pkg_list() {
    grep -vE '^[[:space:]]*(#|$)' "$1" 2>/dev/null |
        sed -E 's/[[:space:]]*#.*$//' |
        awk 'NF'
}
mapfile -t repo < <(pkg_list "$DIR/packages.txt")
mapfile -t aur < <(pkg_list "$DIR/aur.packages.txt")

if ((${#repo[@]})); then
    echo "==> pacman: ${#repo[@]} пакетов"
    sudo pacman -S --needed --noconfirm "${repo[@]}"
else
    echo "==> packages.txt пуст, пропускаю"
fi

if ((${#aur[@]})); then
    helper=""
    if command -v paru >/dev/null 2>&1; then
        helper=paru
    elif command -v yay >/dev/null 2>&1; then
        helper=yay
    fi
    if [ -z "$helper" ]; then
        echo "!! Нужен paru или yay для AUR-пакетов:" >&2
        printf '   %s\n' "${aur[@]}" >&2
        echo "   paru: https://github.com/Morganamilo/paru" >&2
        echo "   yay:  https://github.com/Jguer/yay" >&2
        exit 1
    fi
    echo "==> $helper: ${#aur[@]} AUR-пакетов"
    "$helper" -S --needed --noconfirm "${aur[@]}"
else
    echo "==> aur.packages.txt пуст, пропускаю"
fi

echo "==> Готово. Разложи конфиги: cd ~/dotfiles && ./install.sh --no-packages"
