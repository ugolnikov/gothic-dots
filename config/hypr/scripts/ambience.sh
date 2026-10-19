#!/usr/bin/env bash
# ambience.sh — распорядок дня: палитра, ночной свет, DND и ротация обоев.
#   ambience.sh status                 текущий слот, следующая граница, состояние
#   ambience.sh on|off|toggle          мастер-переключатель (on сразу применяет слот)
#   ambience.sh tick [--at HH:MM] [--dry-run]
#   ambience.sh next [--dry-run]       следующее обои вручную
#   ambience.sh daemon                 тикать каждые AMBIENCE_POLL секунд (autostart)
#   ambience.sh config                 действующие настройки
#
# Модуль владеет только «когда»: палитру меняет palette.sh, ночной свет и DND —
# controls.sh, обои — theme.sh. Слот пишется в маркер и не применяется дважды:
# ручная правка палитры живёт до следующей границы. Пока нет маркера
# ~/.config/hypr/ambience, tick ничего не делает.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$CONFIG/hypr"
SCRIPTS="${AMBIENCE_SCRIPTS:-$STATE/scripts}"
# До install.sh ~/.config/hypr ещё не симлинк: тогда модули лежат рядом с этим
# скриптом, и распорядок работает прямо из чекаута.
if [ -z "${AMBIENCE_SCRIPTS:-}" ] && [ ! -d "$SCRIPTS" ]; then
    SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
CONF_FILE="${AMBIENCE_CONF:-$STATE/ambience.conf}"
MASTER="$STATE/ambience"
SLOT_MARKER="$STATE/ambience-slot"
WALL_MARKER="$STATE/ambience-wall"
ROTATED_MARKER="$STATE/ambience-rotated"

DRY=0

usage() {
    cat >&2 <<'EOF'
usage: ambience.sh status|on|off|toggle|config
       ambience.sh tick [--at HH:MM] [--dry-run]
       ambience.sh next [--dry-run]
       ambience.sh daemon
EOF
    exit 2
}

die() {
    echo "ambience.sh: $*" >&2
    exit 2
}

note() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "Распорядок" "$1" >/dev/null 2>&1 || true
    return 0
}

reset_config() {
    DAY_START=07:30
    EVENING_START=19:00
    NIGHT_START=22:30
    DAY_PALETTE=
    EVENING_PALETTE=
    NIGHT_PALETTE=
    NIGHT_TEMP=3500
    NIGHT_LIGHT=auto
    DND=off
    ROTATE_DIR=
    ROTATE_INTERVAL=1800
    ROTATE_ORDER=random
}

# load_config — простые KEY=VALUE без inline-комментариев; ключи
# регистронезависимы, значения обрезаются по краям.
load_config() {
    reset_config
    [ -r "$CONF_FILE" ] || return 0
    local line key value
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in '' | '#'*) continue ;; esac
        case "$line" in *=*) ;; *) continue ;; esac
        key="$(printf '%s' "${line%%=*}" | tr -d '[:space:]')"
        value="${line#*=}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        case "${key,,}" in
            day_start) DAY_START="$value" ;;
            evening_start) EVENING_START="$value" ;;
            night_start) NIGHT_START="$value" ;;
            day_palette) DAY_PALETTE="$value" ;;
            evening_palette) EVENING_PALETTE="$value" ;;
            night_palette) NIGHT_PALETTE="$value" ;;
            night_temp) NIGHT_TEMP="$value" ;;
            night_light) NIGHT_LIGHT="$value" ;;
            dnd) DND="$value" ;;
            rotate_dir) ROTATE_DIR="$value" ;;
            rotate_interval) ROTATE_INTERVAL="$value" ;;
            rotate_order) ROTATE_ORDER="$value" ;;
            *) : ;;
        esac
    done <"$CONF_FILE"
}

to_min() {
    local t="${1:-}"
    case "$t" in
        [0-9]:[0-5][0-9] | [0-9][0-9]:[0-5][0-9]) ;;
        *) die "время должно быть HH:MM: '$t'" ;;
    esac
    printf '%s\n' "$((10#${t%%:*} * 60 + 10#${t##*:}))"
}

validate_config() {
    local d e n
    d="$(to_min "$DAY_START")"
    e="$(to_min "$EVENING_START")"
    n="$(to_min "$NIGHT_START")"
    if [ "$d" -ge "$e" ] || [ "$e" -ge "$n" ]; then
        die "границы должны идти по возрастанию: day_start < evening_start < night_start"
    fi
    case "$NIGHT_LIGHT" in auto | on | off) ;; *) die "night_light: auto|on|off" ;; esac
    case "$DND" in auto | on | off) ;; *) die "dnd: auto|on|off" ;; esac
    case "$ROTATE_ORDER" in random | sequential) ;; *) die "rotate_order: random|sequential" ;; esac
    case "$ROTATE_INTERVAL" in '' | *[!0-9]*) die "rotate_interval: секунды числом" ;; esac
    case "$NIGHT_TEMP" in '' | *[!0-9]*) die "night_temp: кельвины числом" ;; esac
    local pal
    for pal in "$DAY_PALETTE" "$EVENING_PALETTE" "$NIGHT_PALETTE"; do
        case "$pal" in '' | dark | light | dynamic) ;; *) die "палитра: dark|light|dynamic или пусто" ;; esac
    done
}

now_min() {
    local t h m
    if [ -n "${AMBIENCE_NOW:-}" ]; then
        to_min "$AMBIENCE_NOW"
        return
    fi
    t="$(date +%H:%M)"
    h="${t%%:*}"
    m="${t##*:}"
    printf '%s\n' "$((10#$h * 60 + 10#$m))"
}

now_epoch() {
    if [ -n "${AMBIENCE_EPOCH:-}" ]; then
        case "$AMBIENCE_EPOCH" in
            '' | *[!0-9]*) die "AMBIENCE_EPOCH: секунды числом" ;;
        esac
        printf '%s\n' "$AMBIENCE_EPOCH"
        return
    fi
    date +%s
}

hhmm() {
    printf '%02d:%02d\n' "$(($1 / 60 % 24))" "$(($1 % 60))"
}

# slot_at <minutes> — ночь заворачивается через полночь: до day_start тоже ночь.
slot_at() {
    local n="$1" d e ni
    d="$(to_min "$DAY_START")"
    e="$(to_min "$EVENING_START")"
    ni="$(to_min "$NIGHT_START")"
    if [ "$n" -ge "$ni" ] || [ "$n" -lt "$d" ]; then
        echo night
    elif [ "$n" -ge "$e" ]; then
        echo evening
    else
        echo day
    fi
}

next_boundary() {
    local n="$1" d e ni t
    d="$(to_min "$DAY_START")"
    e="$(to_min "$EVENING_START")"
    ni="$(to_min "$NIGHT_START")"
    for t in "$d" "$e" "$ni"; do
        if [ "$t" -gt "$n" ]; then
            hhmm "$t"
            return
        fi
    done
    hhmm "$((d + 1440))"
}

slot_window() {
    case "$1" in
        day) printf '%s–%s\n' "$DAY_START" "$EVENING_START" ;;
        evening) printf '%s–%s\n' "$EVENING_START" "$NIGHT_START" ;;
        night) printf '%s–%s\n' "$NIGHT_START" "$DAY_START" ;;
    esac
}

# ── Действия над чужими модулями ────────────────────────────────────────────
run() {
    if [ "$DRY" = 1 ]; then
        printf '  %s %s\n' "${1##*/}" "${*:2}"
        return 0
    fi
    "$@" >/dev/null 2>&1 || true
}

apply_slot() {
    local slot="$1" pal nl dnd
    case "$slot" in
        day) pal="$DAY_PALETTE" ;;
        evening) pal="$EVENING_PALETTE" ;;
        night) pal="$NIGHT_PALETTE" ;;
    esac
    if [ -n "$pal" ]; then
        run "$SCRIPTS/palette.sh" set "$pal"
    fi

    case "$NIGHT_LIGHT" in
        auto) if [ "$slot" = night ]; then nl=on; else nl=off; fi ;;
        *) nl="$NIGHT_LIGHT" ;;
    esac
    run "$SCRIPTS/controls.sh" night "$nl" "$NIGHT_TEMP"

    case "$DND" in
        auto) if [ "$slot" = night ]; then dnd=on; else dnd=off; fi ;;
        *) dnd="$DND" ;;
    esac
    run "$SCRIPTS/controls.sh" dnd "$dnd"
}

# ── Обои ────────────────────────────────────────────────────────────────────
pick_wallpaper() {
    local dir="$1" current i p
    local -a pics=() pool=()
    mapfile -t pics < <(
        find "$dir" -maxdepth 2 -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
            2>/dev/null | sort
    )
    [ "${#pics[@]}" -gt 0 ] || return 1

    current="$(cat "$WALL_MARKER" 2>/dev/null || true)"
    if [ "$ROTATE_ORDER" = sequential ]; then
        local idx=0
        for i in "${!pics[@]}"; do
            if [ "${pics[$i]}" = "$current" ]; then
                idx=$(((i + 1) % ${#pics[@]}))
            fi
        done
        printf '%s\n' "${pics[$idx]}"
        return 0
    fi

    for p in "${pics[@]}"; do
        [ "$p" = "$current" ] || pool+=("$p")
    done
    [ "${#pool[@]}" -gt 0 ] || pool=("${pics[@]}")
    printf '%s\n' "${pool[$((RANDOM % ${#pool[@]}))]}"
}

rotate_wallpaper() {
    local dir next
    dir="${ROTATE_DIR/#\~/$HOME}"
    [ -d "$dir" ] || {
        echo "ambience.sh: нет каталога обоев: $dir" >&2
        return 1
    }
    next="$(pick_wallpaper "$dir")" || return 1

    if [ "$DRY" = 1 ]; then
        printf '  theme.sh %s\n' "$next"
        return 0
    fi
    "$SCRIPTS/theme.sh" "$next" >/dev/null 2>&1 || true
    mkdir -p "$STATE"
    printf '%s\n' "$next" >"$WALL_MARKER"
    now_epoch >"$ROTATED_MARKER"
    note "Обои: $(basename "$next")"
}

maybe_rotate() {
    local last now
    [ -n "$ROTATE_DIR" ] || return 0
    [ "$ROTATE_INTERVAL" -gt 0 ] || return 0
    last="$(cat "$ROTATED_MARKER" 2>/dev/null || echo 0)"
    case "$last" in '' | *[!0-9]*) last=0 ;; esac
    now="$(now_epoch)"
    [ "$((now - last))" -ge "$ROTATE_INTERVAL" ] || return 0
    rotate_wallpaper || true
}

# ── Тик ─────────────────────────────────────────────────────────────────────
tick() {
    load_config
    validate_config
    local now slot prev

    if [ "$DRY" = 0 ] && [ ! -e "$MASTER" ]; then
        return 0
    fi

    now="$(now_min)"
    slot="$(slot_at "$now")"
    prev="$(cat "$SLOT_MARKER" 2>/dev/null || true)"

    if [ "$DRY" = 1 ]; then
        printf 'ambience: %s — слот %s (ничего не изменено)\n' "$(hhmm "$now")" "$slot"
        maybe_rotate
        apply_slot "$slot"
        return 0
    fi

    maybe_rotate
    [ "$slot" != "$prev" ] || return 0

    apply_slot "$slot"
    mkdir -p "$STATE"
    printf '%s\n' "$slot" >"$SLOT_MARKER"
    note "Слот: $slot"
}

status() {
    load_config
    validate_config
    local now slot state pal night dnd
    now="$(now_min)"
    slot="$(slot_at "$now")"
    if [ -e "$MASTER" ]; then state=вкл; else state=выкл; fi

    printf 'ambience: %s\n' "$state"
    printf 'слот: %s (%s)\n' "$slot" "$(slot_window "$slot")"
    printf 'сейчас: %s, следующая граница: %s\n' "$(hhmm "$now")" "$(next_boundary "$now")"
    pal="$("$SCRIPTS/palette.sh" status 2>/dev/null || echo '?')"
    printf 'палитра: %s\n' "$pal"
    night="$("$SCRIPTS/controls.sh" get night 2>/dev/null || echo '?')"
    dnd="$("$SCRIPTS/controls.sh" get dnd 2>/dev/null || echo '?')"
    printf 'ночной свет: %s, dnd: %s\n' "$night" "$dnd"
    if [ -n "$ROTATE_DIR" ]; then
        printf 'обои: %s каждые %ss (%s)\n' "$ROTATE_DIR" "$ROTATE_INTERVAL" "$ROTATE_ORDER"
    else
        printf 'обои: ротация выключена\n'
    fi
}

print_config() {
    load_config
    validate_config
    printf 'day_start=%s\n' "$DAY_START"
    printf 'evening_start=%s\n' "$EVENING_START"
    printf 'night_start=%s\n' "$NIGHT_START"
    printf 'day_palette=%s\n' "$DAY_PALETTE"
    printf 'evening_palette=%s\n' "$EVENING_PALETTE"
    printf 'night_palette=%s\n' "$NIGHT_PALETTE"
    printf 'night_temp=%s\n' "$NIGHT_TEMP"
    printf 'night_light=%s\n' "$NIGHT_LIGHT"
    printf 'dnd=%s\n' "$DND"
    printf 'rotate_dir=%s\n' "$ROTATE_DIR"
    printf 'rotate_interval=%s\n' "$ROTATE_INTERVAL"
    printf 'rotate_order=%s\n' "$ROTATE_ORDER"
}

daemon() {
    while :; do
        tick || true
        sleep "${AMBIENCE_POLL:-300}"
    done
}

main() {
    local cmd="${1:-status}"
    case "$cmd" in
        status) status ;;
        on)
            load_config
            validate_config
            mkdir -p "$STATE"
            : >"$MASTER"
            rm -f "$SLOT_MARKER"
            tick
            note "Распорядок включён"
            ;;
        off)
            rm -f "$MASTER" "$SLOT_MARKER"
            note "Распорядок выключен"
            ;;
        toggle)
            if [ -e "$MASTER" ]; then
                main off
            else
                main on
            fi
            ;;
        tick)
            shift || true
            while [ $# -gt 0 ]; do
                case "$1" in
                    --at)
                        [ -n "${2:-}" ] || usage
                        AMBIENCE_NOW="$2"
                        shift
                        ;;
                    --dry-run) DRY=1 ;;
                    *) usage ;;
                esac
                shift
            done
            tick
            ;;
        next)
            shift || true
            [ "${1:-}" = --dry-run ] && DRY=1
            load_config
            validate_config
            rotate_wallpaper
            ;;
        daemon) daemon ;;
        config) print_config ;;
        *) usage ;;
    esac
}

main "$@"
