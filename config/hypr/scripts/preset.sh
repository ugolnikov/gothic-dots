#!/usr/bin/env bash
# preset.sh — именованные наборы настроек рабочего стола с откатом.
#   preset.sh apply <name>     применить пресет (снимок текущего состояния — до)
#   preset.sh off              вернуть состояние, снятое при apply
#   preset.sh current          активный пресет (пусто, если нет)
#   preset.sh list             встроенные и пользовательские пресеты
#   preset.sh show <name>      что внутри
#   preset.sh menu             rofi-меню (SUPER + Shift + P)
#
# Пресет — KEY=VALUE: palette, animations, night, dnd, caffeine, bar, power.
# Встроенные лежат в config/hypr/presets/, пользовательские — в
# ~/.config/hypr/presets.local/ (вне git, перекрывают встроенные по имени).
# Применение снимает снимок только тех ключей, которые есть в пресете, и
# пишет его в preset-previous; off проигрывает снимок обратно. Второй apply
# сначала снимает предыдущий пресет, поэтому снимок всегда относится к
# состоянию «до первого пресета».
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$CONFIG/hypr"
SCRIPTS="${PRESET_SCRIPTS:-$STATE/scripts}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# До install.sh ~/.config/hypr ещё не симлинк: берём модули и встроенные
# пресеты из чекаута рядом с этим скриптом.
if [ -z "${PRESET_SCRIPTS:-}" ] && [ ! -d "$SCRIPTS" ]; then
    SCRIPTS="$HERE"
fi
BUILTIN="$STATE/presets"
if [ ! -d "$BUILTIN" ] && [ -d "$HERE/../presets" ]; then
    BUILTIN="$HERE/../presets"
fi
LOCAL="$STATE/presets.local"
ACTIVE="$STATE/preset-active"
PREVIOUS="$STATE/preset-previous"
ROFI_THEME="${PRESET_ROFI_THEME:-$CONFIG/rofi/settings.rasi}"

usage() {
    cat >&2 <<'EOF'
usage: preset.sh apply <name> | off | current | list | show <name> | menu
EOF
    exit 2
}

die() {
    echo "preset.sh: $*" >&2
    exit 2
}

warn() {
    echo "preset.sh: $*" >&2
}

note() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "Пресет" "$1" >/dev/null 2>&1 || true
    return 0
}

valid_name() {
    case "${1:-}" in
        '' | *[!A-Za-z0-9_-]*) return 1 ;;
    esac
    [ "${#1}" -le 32 ]
}

find_preset() {
    local name="$1"
    if [ -r "$LOCAL/$name.conf" ]; then
        printf '%s\n' "$LOCAL/$name.conf"
    elif [ -r "$BUILTIN/$name.conf" ]; then
        printf '%s\n' "$BUILTIN/$name.conf"
    else
        return 1
    fi
}

list_names() {
    {
        [ -d "$BUILTIN" ] && find "$BUILTIN" -maxdepth 1 -type f -name '*.conf' -printf '%f\n' 2>/dev/null
        [ -d "$LOCAL" ] && find "$LOCAL" -maxdepth 1 -type f -name '*.conf' -printf '%f\n' 2>/dev/null
    } | sed 's/\.conf$//' | sort -u
}

# validate_pair <key> <value> — неизвестный ключ или значение отсекаются до
# первого изменения состояния, а не посреди применения.
validate_pair() {
    local key="$1" value="$2"
    case "$key" in
        palette)
            case "$value" in dark | light | dynamic) ;; *) die "palette: dark|light|dynamic" ;; esac
            ;;
        animations | night | dnd | caffeine | bar)
            case "$value" in on | off) ;; *) die "$key: on|off" ;; esac
            ;;
        power)
            case "$value" in performance | balanced | power-saver) ;; *) die "power: performance|balanced|power-saver" ;; esac
            ;;
        *) die "неизвестный ключ пресета: $key" ;;
    esac
}

# load_preset <file> — в PRESET_KEYS/PRESET_VALUES, с валидацией каждой пары.
load_preset() {
    local file="$1" line key value
    PRESET_KEYS=()
    PRESET_VALUES=()
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in '' | '#'*) continue ;; esac
        case "$line" in *=*) ;; *) die "строка без '=': $line" ;; esac
        key="$(printf '%s' "${line%%=*}" | tr -d '[:space:]')"
        value="${line#*=}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        validate_pair "$key" "$value"
        PRESET_KEYS+=("$key")
        PRESET_VALUES+=("$value")
    done <"$file"
    [ "${#PRESET_KEYS[@]}" -gt 0 ] || die "пресет пуст: $file"
}

current_value() {
    local key="$1"
    case "$key" in
        palette) "$SCRIPTS/palette.sh" status 2>/dev/null || echo dark ;;
        animations) "$SCRIPTS/effects.sh" status 2>/dev/null || echo off ;;
        night | dnd | caffeine) "$SCRIPTS/controls.sh" get "$key" 2>/dev/null || echo off ;;
        bar)
            if command -v pgrep >/dev/null 2>&1 && pgrep -x waybar >/dev/null 2>&1; then
                echo on
            else
                echo off
            fi
            ;;
        power)
            if command -v powerprofilesctl >/dev/null 2>&1; then
                powerprofilesctl get 2>/dev/null || echo balanced
            else
                echo unavailable
            fi
            ;;
        *) echo "" ;;
    esac
}

apply_value() {
    local key="$1" value="$2"
    case "$key" in
        palette) "$SCRIPTS/palette.sh" set "$value" ;;
        animations) "$SCRIPTS/effects.sh" animations "$value" ;;
        night | dnd | caffeine) "$SCRIPTS/controls.sh" "$key" "$value" ;;
        bar)
            if [ "$value" = on ]; then
                if ! command -v pgrep >/dev/null 2>&1 || ! pgrep -x waybar >/dev/null 2>&1; then
                    setsid waybar >/dev/null 2>&1 &
                fi
            else
                pkill -x waybar 2>/dev/null || true
            fi
            ;;
        power)
            if command -v powerprofilesctl >/dev/null 2>&1; then
                powerprofilesctl set "$value" >/dev/null 2>&1 ||
                    warn "powerprofilesctl не принял '$value'"
            elif [ "$value" != unavailable ]; then
                warn "powerprofilesctl не установлен — power пропущен"
            fi
            ;;
    esac
}

snapshot_current() {
    local i key
    mkdir -p "$STATE"
    : >"$PREVIOUS"
    for i in "${!PRESET_KEYS[@]}"; do
        key="${PRESET_KEYS[$i]}"
        printf '%s=%s\n' "$key" "$(current_value "$key")" >>"$PREVIOUS"
    done
    chmod 600 "$PREVIOUS"
}

# restore_previous [quiet] — проиграть снимок и снять маркеры.
restore_previous() {
    local quiet="${1:-}" key value
    if [ ! -r "$PREVIOUS" ]; then
        rm -f "$ACTIVE" "$PREVIOUS"
        return 0
    fi
    while IFS='=' read -r key value; do
        [ -n "$key" ] || continue
        [ "$value" = unavailable ] && continue
        apply_value "$key" "$value"
    done <"$PREVIOUS"
    rm -f "$PREVIOUS" "$ACTIVE"
    [ "$quiet" = quiet ] || {
        echo "preset.sh: пресет снят"
        note "Пресет снят"
    }
}

apply_preset() {
    local name="${1:-}" file i
    valid_name "$name" || die "имя пресета: буквы, цифры, «_» и «-»"
    file="$(find_preset "$name")" || die "нет пресета «$name» — preset.sh list"
    load_preset "$file"

    # Второй пресет не наслаивается на первый: сначала откат, потом новый
    # снимок, иначе off вернул бы состояние предыдущего пресета, а не «до».
    if [ -e "$ACTIVE" ]; then
        restore_previous quiet
    fi

    snapshot_current
    for i in "${!PRESET_KEYS[@]}"; do
        apply_value "${PRESET_KEYS[$i]}" "${PRESET_VALUES[$i]}"
    done
    printf '%s\n' "$name" >"$ACTIVE"
    echo "preset.sh: применён «$name»"
    note "Пресет: $name"
}

current() {
    cat "$ACTIVE" 2>/dev/null || true
}

show_preset() {
    local name="${1:-}" file
    valid_name "$name" || die "имя пресета: буквы, цифры, «_» и «-»"
    file="$(find_preset "$name")" || die "нет пресета «$name»"
    echo "# $name ($file)"
    cat "$file"
}

menu() {
    command -v rofi >/dev/null 2>&1 || die "rofi не установлен"
    local active choice name rows=()
    active="$(current)"
    if [ -n "$active" ]; then
        rows+=("Снять пресет: $active")
    fi
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        rows+=("Применить: $name")
    done < <(list_names)
    [ "${#rows[@]}" -gt 0 ] || die "нет ни одного пресета"

    choice="$(printf '%s\n' "${rows[@]}" | rofi -dmenu -i -p "Пресет" -theme "$ROFI_THEME")" || exit 0
    [ -n "$choice" ] || exit 0
    case "$choice" in
        "Снять пресет:"*) restore_previous ;;
        "Применить: "*)
            name="${choice#Применить: }"
            apply_preset "$name"
            ;;
        *) exit 0 ;;
    esac
}

main() {
    case "${1:-}" in
        apply) apply_preset "${2:-}" ;;
        off)
            if [ -z "$(current)" ] && [ ! -e "$PREVIOUS" ]; then
                echo "preset.sh: активного пресета нет"
                return 0
            fi
            restore_previous
            ;;
        current) current ;;
        list) list_names ;;
        show) show_preset "${2:-}" ;;
        menu) menu ;;
        *) usage ;;
    esac
}

main "$@"
