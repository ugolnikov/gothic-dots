#!/usr/bin/env bash
# monitors.sh — сохранённые раскладки мониторов и их автоприменение.
#   monitors.sh save <name>        снять текущую раскладку
#   monitors.sh apply <name>       применить раскладку
#   monitors.sh list|show <name>|delete <name>
#   monitors.sh current            что подключено сейчас
#   monitors.sh auto <name|off>    применять раскладку при hotplug
#   monitors.sh autoload           применить auto-раскладку (зовёт eventd)
#   monitors.sh menu               выбрать раскладку в rofi
#   monitors.sh status
#
# Раскладка — TSV в ~/.config/hypr/monitors/<name>.tsv: имя, EDID-описание,
# режим, позиция, масштаб, transform, mirror, disabled. При применении выход
# ищется сначала по description (порт может смениться), затем по имени.
# Состояние auto — маркер ~/.config/hypr/monitors-auto с именем раскладки.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$CONFIG/hypr"
DIR="${MONITORS_DIR:-$STATE/monitors}"
AUTO="${MONITORS_AUTO:-$STATE/monitors-auto}"
HYPRCTL="${MONITORS_HYPRCTL:-hyprctl}"
ROFI_THEME="$CONFIG/rofi/settings.rasi"
DELAY="${MONITORS_DELAY:-0.5}"

usage() {
    cat >&2 <<'EOF'
usage: monitors.sh save <name>
       monitors.sh apply <name>
       monitors.sh list|show <name>|delete <name>
       monitors.sh current
       monitors.sh auto <name|off>
       monitors.sh autoload
       monitors.sh menu
       monitors.sh status
EOF
    exit 2
}

die() {
    echo "monitors.sh: $*" >&2
    exit 1
}

profile_file() {
    case "$1" in '' | */* | .* | *..*) die "недопустимое имя раскладки: $1" ;; esac
    printf '%s/%s.tsv\n' "$DIR" "$1"
}

save_profile() {
    local name="$1" file tmp json
    file="$(profile_file "$name")"
    mkdir -p "$DIR"
    json="$(mktemp "$DIR/.monitors.XXXXXX")"
    tmp="$(mktemp "$DIR/.profile.XXXXXX")"
    "$HYPRCTL" monitors -j >"$json" 2>/dev/null || {
        rm -f "$json" "$tmp"
        die "hyprctl monitors недоступен"
    }
    printf '# name<TAB>description<TAB>mode<TAB>position<TAB>scale<TAB>transform<TAB>mirror<TAB>disabled\n' >"$tmp"
    jq -r '.[] | [
        .name,
        (if (.description // "") == "" then "-" else .description end),
        "\(.width)x\(.height)@\(((.refreshRate * 100 | round) / 100))",
        "\(.x)x\(.y)",
        (.scale | tostring),
        (.transform | tostring),
        (if (.mirrorOf // "none") == "none" then "-" else .mirrorOf end),
        (if .disabled then 1 else 0 end)
    ] | @tsv' "$json" >>"$tmp"
    chmod 600 "$tmp"
    mv -f "$tmp" "$file"
    rm -f "$json"
}

# find_current <description> <name> — имя выхода в текущей сессии.
find_current() {
    local description="$1" name="$2" found=""
    if [ -n "$description" ]; then
        found="$(printf '%s' "$CURRENT_JSON" | jq -r --arg d "$description" '
            .[] | select(.description == $d) | .name
        ' 2>/dev/null | head -n 1)"
    fi
    if [ -z "$found" ]; then
        found="$(printf '%s' "$CURRENT_JSON" | jq -r --arg n "$name" '
            .[] | select(.name == $n) | .name
        ' 2>/dev/null | head -n 1)"
    fi
    printf '%s\n' "$found"
}

apply_profile() {
    local name="$1" file saved_name desc mode pos scale transform mirror disabled
    local target spec
    local -A map=()
    file="$(profile_file "$name")"
    [ -r "$file" ] || die "нет раскладки: $file"
    CURRENT_JSON="$("$HYPRCTL" monitors -j 2>/dev/null)" || die "hyprctl monitors недоступен"

    # Сначала сопоставить сохранённые имена с текущими: mirror ссылается на
    # сохранённое имя, а после смены порта оно другое.
    while IFS=$'\t' read -r saved_name desc mode pos scale transform mirror disabled; do
        case "$saved_name" in '' | '#'*) continue ;; esac
        if [ "$desc" = "-" ]; then desc=""; fi
        if [ "$mirror" = "-" ]; then mirror=""; fi
        map["$saved_name"]="$(find_current "$desc" "$saved_name")"
    done <"$file"

    # Включённые — первыми, выключенные — последними.
    while IFS=$'\t' read -r saved_name desc mode pos scale transform mirror disabled; do
        case "$saved_name" in '' | '#'*) continue ;; esac
        [ "$disabled" = 1 ] && continue
        if [ "$mirror" = "-" ]; then mirror=""; fi
        target="${map[$saved_name]:-}"
        [ -n "$target" ] || continue
        spec="$target,$mode,$pos,${scale:-1},transform,${transform:-0}"
        if [ -n "$mirror" ] && [ -n "${map[$mirror]:-}" ]; then
            spec="$spec,mirror,${map[$mirror]}"
        fi
        "$HYPRCTL" keyword monitor "$spec" >/dev/null 2>&1 || true
    done <"$file"

    while IFS=$'\t' read -r saved_name desc mode pos scale transform mirror disabled; do
        case "$saved_name" in '' | '#'*) continue ;; esac
        [ "$disabled" = 1 ] || continue
        target="${map[$saved_name]:-}"
        [ -n "$target" ] || continue
        "$HYPRCTL" keyword monitor "$target,disable" >/dev/null 2>&1 || true
    done <"$file"
}

auto_profile() {
    [ -r "$AUTO" ] || return 0
    tr -d '[:space:]' <"$AUTO"
}

autoload() {
    local name
    name="$(auto_profile)"
    [ -n "$name" ] || return 0
    sleep "$DELAY"
    apply_profile "$name"
}

set_auto() {
    local name="$1"
    case "$name" in
        off | '')
            rm -f "$AUTO"
            return 0
            ;;
    esac
    profile_file "$name" >/dev/null
    [ -r "$DIR/$name.tsv" ] || die "нет раскладки: $name"
    mkdir -p "$STATE"
    printf '%s\n' "$name" >"$AUTO"
}

list_profiles() {
    [ -d "$DIR" ] || return 0
    find "$DIR" -maxdepth 1 -name '*.tsv' -printf '%f\n' 2>/dev/null |
        sed 's/\.tsv$//' | sort
}

current() {
    local json
    json="$("$HYPRCTL" monitors -j 2>/dev/null)" || die "hyprctl monitors недоступен"
    printf '%s' "$json" | jq -r '.[] |
        "\(.name)\t\(.description // "")\t\(.width)x\(.height)@\(.refreshRate)\t\(.x)x\(.y)\t\(.scale)"
    ' 2>/dev/null || die "не удалось разобрать ответ hyprctl"
}

menu() {
    local choice
    command -v rofi >/dev/null 2>&1 || die "rofi не установлен"
    choice="$(list_profiles | rofi -dmenu -i -p "Мониторы" -theme "$ROFI_THEME")" || exit 0
    [ -n "$choice" ] || exit 0
    apply_profile "$choice"
}

status() {
    local auto count=0
    auto="$(auto_profile)"
    if [ -d "$DIR" ]; then
        count="$(find "$DIR" -maxdepth 1 -name '*.tsv' 2>/dev/null | wc -l)"
    fi
    printf 'раскладки: %s\n' "$DIR"
    printf 'сохранено: %s\n' "$count"
    printf 'автоприменение: %s\n' "${auto:-выключено}"
}

main() {
    case "${1:-status}" in
        save)
            [ -n "${2:-}" ] || usage
            save_profile "$2"
            ;;
        apply)
            [ -n "${2:-}" ] || usage
            apply_profile "$2"
            ;;
        list) list_profiles ;;
        show)
            [ -n "${2:-}" ] || usage
            cat "$(profile_file "$2")"
            ;;
        delete)
            [ -n "${2:-}" ] || usage
            rm -f "$(profile_file "$2")"
            if [ "$(auto_profile)" = "$2" ]; then
                rm -f "$AUTO"
            fi
            ;;
        current) current ;;
        auto)
            [ -n "${2:-}" ] || usage
            set_auto "$2"
            ;;
        autoload) autoload ;;
        menu) menu ;;
        status) status ;;
        *) usage ;;
    esac
}

main "$@"
