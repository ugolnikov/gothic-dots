#!/usr/bin/env bash
# controls.sh — переключатели сессии: «не беспокоить», ночной свет, кофеин, запись.
#   controls.sh status                        состояние всех переключателей
#   controls.sh get <dnd|night|caffeine|recording>
#   controls.sh indicators                    компактная строка для Waybar
#   controls.sh dnd [on|off|toggle]
#   controls.sh night [on|off|toggle] [K]
#   controls.sh caffeine [on|off|toggle]
#   controls.sh record [start [full|region] [audio] | stop | toggle [full|region] [audio]]
#   controls.sh restore                       вернуть переключатели после входа
#   controls.sh reset                         выключить всё
#
# Состояние живёт в маркерах ~/.config/hypr: dnd — пустой файл, night-light и
# caffeine — PID демона, recording — «PID<TAB>файл». Маркер остаётся
# единственным местом, где переключатель хранит состояние: панель, Waybar и
# doctor спрашивают его через `get`, а не читают файлы сами.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$CONFIG/hypr"
DND_MARKER="$STATE/dnd"
NIGHT_MARKER="$STATE/night-light"
CAFFEINE_MARKER="$STATE/caffeine"
REC_MARKER="$STATE/recording"
NOTIF_MARKER="$STATE/notifications"
REC_DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
DEFAULT_TEMP=4000

# restore/reset проходят через те же сеттеры, но не должны сыпать
# уведомлениями на входе или при общем сбросе.
QUIET=0

usage() {
    cat >&2 <<'EOF'
usage: controls.sh status|get <name>|indicators|restore|reset
       controls.sh dnd [on|off|toggle]
       controls.sh night [on|off|toggle] [temperature]
       controls.sh caffeine [on|off|toggle]
       controls.sh record [start [full|region] [audio]|stop|toggle [full|region] [audio]]
EOF
    exit 2
}

die() {
    echo "controls.sh: $*" >&2
    note "$*"
    exit 2
}

note() {
    [ "$QUIET" = 1 ] && return 0
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "Переключатели" "$1" >/dev/null 2>&1 || true
    return 0
}

alive() {
    local pid="${1:-}"
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

marker_pid() {
    local f="${1:-}"
    [ -r "$f" ] || return 0
    cut -f1 "$f" 2>/dev/null || true
}

# stop_pid <marker> — остановить записанный процесс: TERM, до секунды
# ожидания, затем KILL. Маркер не трогает: это дело вызывающего.
stop_pid() {
    local pid
    pid="$(marker_pid "$1")"
    alive "$pid" || return 0
    kill -TERM "$pid" 2>/dev/null || true
    for _ in {1..20}; do
        alive "$pid" || return 0
        sleep 0.05
    done
    kill -KILL "$pid" 2>/dev/null || true
    return 0
}

# stop_group <marker> — то же для лидера группы: systemd-inhibit держит
# блокировку, пока жив его `sleep`, поэтому гасим всю группу целиком.
stop_group() {
    local pid
    pid="$(marker_pid "$1")"
    alive "$pid" || return 0
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
    for _ in {1..20}; do
        alive "$pid" || return 0
        sleep 0.05
    done
    kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
    return 0
}

# ── Не беспокоить ────────────────────────────────────────────────────────────
dnd_is_on() {
    [ -e "$DND_MARKER" ]
}

notifications_daemon() {
    cat "$NOTIF_MARKER" 2>/dev/null || echo mako
}

# dnd_apply <on|off> — передать режим текущему демону уведомлений. Демон
# может быть не запущен: это не ошибка, маркер всё равно хранит выбор.
dnd_apply() {
    case "$(notifications_daemon)" in
        swaync)
            command -v swaync-client >/dev/null 2>&1 || return 0
            if [ "$1" = on ]; then
                swaync-client --dnd-on >/dev/null 2>&1 || true
            else
                swaync-client --dnd-off >/dev/null 2>&1 || true
            fi
            ;;
        *)
            command -v makoctl >/dev/null 2>&1 || return 0
            if [ "$1" = on ]; then
                makoctl mode -a do-not-disturb >/dev/null 2>&1 || true
            else
                makoctl mode -r do-not-disturb >/dev/null 2>&1 || true
            fi
            ;;
    esac
}

set_dnd() {
    case "${1:-toggle}" in
        on)
            mkdir -p "$STATE"
            : >"$DND_MARKER"
            dnd_apply on
            note "Не беспокоить: вкл"
            ;;
        off)
            rm -f "$DND_MARKER"
            dnd_apply off
            note "Не беспокоить: выкл"
            ;;
        toggle)
            if dnd_is_on; then set_dnd off; else set_dnd on; fi
            ;;
        *) usage ;;
    esac
}

# ── Ночной свет ──────────────────────────────────────────────────────────────
night_is_on() {
    alive "$(marker_pid "$NIGHT_MARKER")"
}

set_night() { # set_night <on|off|toggle> [temperature]
    local action="${1:-toggle}" temp="${2:-$DEFAULT_TEMP}"
    case "$action" in
        on)
            command -v hyprsunset >/dev/null 2>&1 ||
                die "hyprsunset не установлен — pacman -S hyprsunset"
            case "$temp" in
                '' | *[!0-9]*) die "температура должна быть целым числом: $temp" ;;
            esac
            if [ "$temp" -lt 1000 ] || [ "$temp" -gt 10000 ]; then
                die "температура вне диапазона 1000..10000K: $temp"
            fi
            stop_pid "$NIGHT_MARKER"
            pkill -x hyprsunset 2>/dev/null || true
            mkdir -p "$STATE"
            setsid hyprsunset -t "$temp" >/dev/null 2>&1 &
            echo "$!" >"$NIGHT_MARKER"
            sleep 0.3
            if ! night_is_on; then
                rm -f "$NIGHT_MARKER"
                die "hyprsunset не запустился (нужен Hyprland >= 0.45)"
            fi
            note "Ночной свет: вкл (${temp}K)"
            ;;
        off)
            stop_pid "$NIGHT_MARKER"
            pkill -x hyprsunset 2>/dev/null || true
            rm -f "$NIGHT_MARKER"
            note "Ночной свет: выкл"
            ;;
        toggle)
            if night_is_on; then set_night off; else set_night on "$temp"; fi
            ;;
        *) usage ;;
    esac
}

# ── Кофеин ───────────────────────────────────────────────────────────────────
caffeine_is_on() {
    alive "$(marker_pid "$CAFFEINE_MARKER")"
}

set_caffeine() {
    case "${1:-toggle}" in
        on)
            command -v systemd-inhibit >/dev/null 2>&1 ||
                die "systemd-inhibit не найден (пакет systemd)"
            mkdir -p "$STATE"
            stop_group "$CAFFEINE_MARKER"
            setsid systemd-inhibit --what=idle:sleep --who=gothic-dots \
                --why="Caffeine: не гасить экран" --mode=block sleep infinity \
                >/dev/null 2>&1 &
            echo "$!" >"$CAFFEINE_MARKER"
            note "Кофеин: вкл — экран не гаснет"
            ;;
        off)
            stop_group "$CAFFEINE_MARKER"
            rm -f "$CAFFEINE_MARKER"
            note "Кофеин: выкл"
            ;;
        toggle)
            if caffeine_is_on; then set_caffeine off; else set_caffeine on; fi
            ;;
        *) usage ;;
    esac
}

# ── Запись экрана ────────────────────────────────────────────────────────────
record_is_on() {
    alive "$(marker_pid "$REC_MARKER")"
}

record_file() {
    [ -r "$REC_MARKER" ] || return 0
    cut -f2 "$REC_MARKER" 2>/dev/null || true
}

record_start() { # record_start [full|region] [audio]
    local mode="${1:-full}" audio="${2:-}" geom="" file pid
    local args=()

    command -v wf-recorder >/dev/null 2>&1 ||
        die "wf-recorder не установлен — pacman -S wf-recorder"
    if record_is_on; then
        die "запись уже идёт: $(record_file)"
    fi

    case "$mode" in
        full) ;;
        region)
            command -v slurp >/dev/null 2>&1 ||
                die "для записи области нужен slurp"
            geom="$(slurp)" || return 0
            [ -n "$geom" ] || return 0
            args+=(-g "$geom")
            ;;
        *) usage ;;
    esac
    [ "$audio" = audio ] && args+=(--audio)

    mkdir -p "$REC_DIR"
    file="$REC_DIR/$(date +%Y-%m-%d_%H-%M-%S).mp4"
    setsid wf-recorder -f "$file" "${args[@]}" >/dev/null 2>&1 &
    pid=$!
    printf '%s\t%s\n' "$pid" "$file" >"$REC_MARKER"
    sleep 0.3
    if ! record_is_on; then
        rm -f "$REC_MARKER"
        die "wf-recorder не запустился"
    fi
    note "Запись экрана: $(basename "$file")"
}

record_stop() {
    local pid file
    [ -e "$REC_MARKER" ] || return 0
    pid="$(marker_pid "$REC_MARKER")"
    file="$(record_file)"
    if alive "$pid"; then
        # SIGINT — штатная остановка wf-recorder: он дописывает контейнер.
        kill -INT "$pid" 2>/dev/null || true
        for _ in {1..20}; do
            alive "$pid" || break
            sleep 0.1
        done
        if alive "$pid"; then
            kill -TERM "$pid" 2>/dev/null || true
            for _ in {1..20}; do
                alive "$pid" || break
                sleep 0.05
            done
        fi
    fi
    rm -f "$REC_MARKER"
    [ -n "$file" ] && note "Запись сохранена: $(basename "$file")"
    return 0
}

record_toggle() {
    if record_is_on; then
        record_stop
    else
        record_start "${1:-full}" "${2:-}"
    fi
}

# ── Состояние ────────────────────────────────────────────────────────────────
get_state() {
    local name="${1:-}"
    case "$name" in
        dnd) if dnd_is_on; then echo on; else echo off; fi ;;
        night) if night_is_on; then echo on; else echo off; fi ;;
        caffeine) if caffeine_is_on; then echo on; else echo off; fi ;;
        recording) if record_is_on; then echo on; else echo off; fi ;;
        *) usage ;;
    esac
}

state_word() {
    if [ "$1" = on ]; then echo вкл; else echo выкл; fi
}

status() {
    local rec file
    rec="$(get_state recording)"
    printf 'dnd: %s\n' "$(state_word "$(get_state dnd)")"
    printf 'night: %s\n' "$(state_word "$(get_state night)")"
    printf 'caffeine: %s\n' "$(state_word "$(get_state caffeine)")"
    if [ "$rec" = on ]; then
        file="$(record_file)"
        printf 'recording: вкл (%s)\n' "${file##*/}"
    else
        printf 'recording: выкл\n'
    fi
}

# indicators — только активные переключатели, через разделитель. Пустой вывод
# Waybar скрывает сам (hide-empty-text), поэтому в покое панель не растёт.
indicators() {
    local out="" tag
    local tags=()
    if dnd_is_on; then tags+=("DND"); fi
    if night_is_on; then tags+=("NIGHT"); fi
    if caffeine_is_on; then tags+=("CAFFEINE"); fi
    if record_is_on; then tags+=("REC"); fi
    [ "${#tags[@]}" -gt 0 ] || return 0
    for tag in "${tags[@]}"; do
        if [ -n "$out" ]; then out+=" · "; fi
        out+="$tag"
    done
    printf '%s\n' "$out"
}

# restore — вернуть переключатели, пережившие вход только маркером: сами
# демоны после логаута не живут, поэтому запускаем их заново.
restore() {
    QUIET=1
    if dnd_is_on; then dnd_apply on; fi
    if [ -e "$NIGHT_MARKER" ] && command -v hyprsunset >/dev/null 2>&1; then
        set_night on
    fi
    if [ -e "$CAFFEINE_MARKER" ] && command -v systemd-inhibit >/dev/null 2>&1; then
        set_caffeine on
    fi
    QUIET=0
    return 0
}

reset_all() {
    QUIET=1
    set_dnd off
    set_night off
    set_caffeine off
    record_stop
    QUIET=0
    return 0
}

main() {
    case "${1:-}" in
        status) status ;;
        get) get_state "${2:-}" ;;
        indicators) indicators ;;
        dnd) set_dnd "${2:-toggle}" ;;
        night) set_night "${2:-toggle}" "${3:-}" ;;
        caffeine) set_caffeine "${2:-toggle}" ;;
        record)
            case "${2:-toggle}" in
                start) record_start "${3:-full}" "${4:-}" ;;
                stop) record_stop ;;
                toggle) record_toggle "${3:-full}" "${4:-}" ;;
                *) usage ;;
            esac
            ;;
        restore) restore ;;
        reset) reset_all ;;
        *) usage ;;
    esac
}

main "$@"
