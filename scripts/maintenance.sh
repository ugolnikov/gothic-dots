#!/usr/bin/env bash
# maintenance.sh — обслуживание райса: снимки, обновление, откат и отчёт.
#   maintenance.sh snapshot [name]        локальный снимок конфигов и пакетов
#   maintenance.sh snapshots              что сохранено
#   maintenance.sh diff [name]            изменения с момента снимка
#   maintenance.sh rollback <name> [--dry-run]
#   maintenance.sh update [--dry-run] [--force]
#   maintenance.sh clean                  только отчёт, ничего не удаляет
#
# Снимок — каталог в ~/.local/state/gothic/snapshots/<name>: tar отслеживаемых
# файлов, SHA коммита, список пакетов и время. update сначала делает снимок,
# потом обновляет систему, затем печатает diff и запускает doctor. rollback
# распаковывает только файлы снимка и не трогает неотслеживаемое; перед откатом
# сам делает снимок pre-rollback, чтобы откат был обратим.
set -euo pipefail

ROOT="${MAINT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE="${MAINT_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/gothic/snapshots}"
DOCTOR="$ROOT/scripts/doctor.sh"

usage() {
    cat >&2 <<'EOF'
usage: maintenance.sh snapshot [name]
       maintenance.sh snapshots
       maintenance.sh diff [name]
       maintenance.sh rollback <name> [--dry-run]
       maintenance.sh update [--dry-run] [--force]
       maintenance.sh clean
EOF
    exit 2
}

die() {
    echo "maintenance.sh: $*" >&2
    exit 2
}

say() {
    printf '%s\n' "$*"
}

valid_name() {
    case "${1:-}" in
        '' | *[!A-Za-z0-9_.-]*) return 1 ;;
    esac
    [ "${#1}" -le 64 ]
}

git_root() {
    git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
        die "не git-репозиторий: $ROOT"
}

# pkg_list — «имя версия» по строке, из pacman или dpkg. Пусто, если нет ни
# того, ни другого: снимок всё равно полезен для конфигов.
pkg_list() {
    if command -v pacman >/dev/null 2>&1; then
        pacman -Q 2>/dev/null || true
    elif command -v dpkg-query >/dev/null 2>&1; then
        dpkg-query -W -f='${Package} ${Version}\n' 2>/dev/null || true
    fi
}

latest_snapshot() {
    [ -d "$STATE" ] || return 1
    find "$STATE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -r | head -n1
}

resolve_snapshot() {
    local name="${1:-}"
    [ -n "$name" ] || name="$(latest_snapshot)" || die "снимков нет"
    [ -n "$name" ] || die "снимков нет"
    valid_name "$name" || die "имя снимка: буквы, цифры, «_», «-», «.»"
    [ -d "$STATE/$name" ] || die "нет снимка «$name» — maintenance.sh snapshots"
    printf '%s\n' "$name"
}

snapshot() {
    local name="${1:-}" dir
    git_root
    [ -n "$name" ] || name="$(date +%Y%m%d-%H%M%S)"
    valid_name "$name" || die "имя снимка: буквы, цифры, «_», «-», «.»"
    dir="$STATE/$name"
    [ ! -e "$dir" ] || die "снимок «$name» уже есть"
    mkdir -p "$dir"
    chmod 700 "$dir"

    git -C "$ROOT" ls-files -z |
        tar -czf "$dir/config.tar.gz" -C "$ROOT" --null -T - ||
        die "не удалось упаковать конфиги"
    git -C "$ROOT" rev-parse HEAD >"$dir/sha" 2>/dev/null || true
    date -u +%Y-%m-%dT%H:%M:%SZ >"$dir/created"
    pkg_list >"$dir/packages.txt"
    printf '%s\n' "$ROOT" >"$dir/root"
    say "$name"
}

list_snapshots() {
    local dir name
    [ -d "$STATE" ] || {
        say "maintenance.sh: снимков нет"
        return 0
    }
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        dir="$STATE/$name"
        printf '%-28s %s  %s\n' "$name" \
            "$(cat "$dir/created" 2>/dev/null || echo '?')" \
            "$(du -sh "$dir" 2>/dev/null | cut -f1)"
    done < <(find "$STATE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -r)
}

diff_snapshot() {
    local name dir current files
    name="$(resolve_snapshot "${1:-}")"
    dir="$STATE/$name"
    say "== пакеты с момента «$name» =="
    current="$(mktemp)"
    pkg_list >"$current"
    awk 'NR == FNR { old[$1] = $2; next }
         { new[$1] = $2 }
         END {
             for (p in new) {
                 if (!(p in old)) print "added    " p " " new[p]
                 else if (old[p] != new[p]) print "upgraded " p " " old[p] " -> " new[p]
             }
             for (p in old) if (!(p in new)) print "removed  " p " " old[p]
         }' "$dir/packages.txt" "$current" | sort -k1,1 -k2,2
    rm -f "$current"

    say ""
    say "== файлы с момента «$name» =="
    files="$(tar -dzf "$dir/config.tar.gz" -C "$ROOT" 2>&1 || true)"
    if [ -n "$files" ]; then
        printf '%s\n' "$files" | sed 's/^/  /'
    else
        say "  без изменений"
    fi
}

rollback() {
    local name="${1:-}" dry=0
    [ "${2:-}" = --dry-run ] && dry=1
    name="$(resolve_snapshot "$name")"
    [ -r "$STATE/$name/config.tar.gz" ] || die "снимок «$name» без архива"

    if [ "$dry" = 1 ]; then
        say "план: распаковать $(tar -tzf "$STATE/$name/config.tar.gz" | wc -l) файлов из «$name» в $ROOT"
        say "перед откатом будет создан снимок pre-rollback-*"
        return 0
    fi

    snapshot "pre-rollback-$(date +%Y%m%d-%H%M%S)" >/dev/null
    tar -xzf "$STATE/$name/config.tar.gz" -C "$ROOT" ||
        die "не удалось распаковать «$name»"
    say "maintenance.sh: конфиги возвращены из «$name»"
}

update() {
    local dry=0 force=0 arg snap
    for arg in "$@"; do
        case "$arg" in
            --dry-run) dry=1 ;;
            --force) force=1 ;;
            *) usage ;;
        esac
    done
    git_root

    if [ -n "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ] && [ "$force" = 0 ]; then
        die "рабочее дерево грязное — закоммить изменения или повтори с --force"
    fi

    snap="pre-update-$(date +%Y%m%d-%H%M%S)"
    if [ "$dry" = 1 ]; then
        say "план: снимок $snap, затем:"
        say "  sudo pacman -Syu"
        say "  paru -Sua | yay -Sua (если установлен)"
        say "  scripts/doctor.sh"
        say "  diff снимка $snap"
        return 0
    fi

    snapshot "$snap" >/dev/null
    say "maintenance.sh: снимок $snap"

    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -Syu || die "pacman -Syu завершился ошибкой"
        if command -v paru >/dev/null 2>&1; then
            paru -Sua || say "maintenance.sh: paru -Sua завершился ошибкой (продолжаем)"
        elif command -v yay >/dev/null 2>&1; then
            yay -Sua || say "maintenance.sh: yay -Sua завершился ошибкой (продолжаем)"
        fi
    else
        say "maintenance.sh: pacman не найден — пакетный шаг пропущен"
    fi

    if [ -x "$DOCTOR" ]; then
        "$DOCTOR" || say "maintenance.sh: doctor нашёл проблемы (см. выше)"
    fi
    diff_snapshot "$snap"
}

clean() {
    say "== кэш ~/.cache (крупнейшее) =="
    if [ -d "$HOME/.cache" ]; then
        du -sh "$HOME"/.cache/* 2>/dev/null | sort -h | tail -n 5 | sed 's/^/  /'
    else
        say "  нет ~/.cache"
    fi
    say ""
    say "== пакеты-сироты =="
    if command -v pacman >/dev/null 2>&1; then
        say "  $(pacman -Qtdq 2>/dev/null | wc -l) шт. (pacman -Qtdq)"
    else
        say "  pacman не найден"
    fi
    say ""
    say "== журнал systemd =="
    if command -v journalctl >/dev/null 2>&1; then
        journalctl --disk-usage 2>/dev/null | sed 's/^/  /' || say "  недоступен"
    else
        say "  journalctl не найден"
    fi
    say ""
    say "maintenance.sh: отчёт только для чтения — ничего не удалено"
}

main() {
    case "${1:-}" in
        snapshot) snapshot "${2:-}" ;;
        snapshots) list_snapshots ;;
        diff) diff_snapshot "${2:-}" ;;
        rollback)
            [ -n "${2:-}" ] || usage
            rollback "$2" "${3:-}"
            ;;
        update)
            shift || true
            update "$@"
            ;;
        clean) clean ;;
        *) usage ;;
    esac
}

main "$@"
