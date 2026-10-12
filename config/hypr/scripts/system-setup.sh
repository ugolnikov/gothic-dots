#!/usr/bin/env bash
# system-setup.sh — установить системные конфиги из etc/ в /etc и включить
# сервисы (zram, systemd-oomd, ananicy-cpp, irqbalance).
# Запуск: install.sh --system  (или напрямую; нужен sudo).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # config/hypr/scripts
ROOT="$(cd "$HERE/../../.." && pwd)"                 # repository root
ETC="$ROOT/etc"

[ -d "$ETC" ] || {
    echo "нет $ETC"
    exit 0
}

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/etc/dotfiles-backup/$STAMP"

echo "==> system files -> /etc (backup: $BACKUP)"
while IFS= read -r -d '' src; do
    rel="${src#"$ETC"/}"
    dst="/etc/$rel"
    if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
        sudo mkdir -p "$BACKUP/$(dirname "$rel")"
        sudo cp -a "$dst" "$BACKUP/$rel"
    fi
    sudo install -Dm644 "$src" "$dst"
done < <(find "$ETC" -type f -print0)

echo "==> services"
sudo systemctl daemon-reload
for svc in systemd-oomd.service ananicy-cpp.service irqbalance.service keyd.service; do
    sudo systemctl enable --now "$svc" 2>/dev/null || echo "  (skip: $svc)"
done
sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true

echo "==> done (zram takes effect on the next boot)"
