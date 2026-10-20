#!/usr/bin/env bash
# osd.sh — громкость и яркость через SwayOSD, если он есть.
#   osd.sh volume up|down|mute
#   osd.sh brightness up|down
#   osd.sh status
#
# SwayOSD рисует индикатор и сам меняет значение; без него модуль делает то же
# самое через wpctl/brightnessctl, просто молча. Поэтому железные клавиши
# всегда работают, а OSD — необязательная оболочка.
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
usage: osd.sh volume <up|down|mute>
       osd.sh brightness <up|down>
       osd.sh status
EOF
    exit 2
}

have() {
    command -v "$1" >/dev/null 2>&1
}

volume() {
    local action="$1"
    case "$action" in
        up)
            have swayosd-client && swayosd-client --output-volume raise && return 0
            have wpctl && wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
            ;;
        down)
            have swayosd-client && swayosd-client --output-volume lower && return 0
            have wpctl && wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
            ;;
        mute)
            have swayosd-client && swayosd-client --output-volume mute-toggle && return 0
            have wpctl && wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
            ;;
        *) usage ;;
    esac
}

brightness() {
    local action="$1"
    case "$action" in
        up)
            have swayosd-client && swayosd-client --brightness raise && return 0
            have brightnessctl && brightnessctl set 5%+
            ;;
        down)
            have swayosd-client && swayosd-client --brightness lower && return 0
            have brightnessctl && brightnessctl set 5%-
            ;;
        *) usage ;;
    esac
}

status() {
    if have swayosd-client; then
        printf 'osd: swayosd\n'
    else
        printf 'osd: выключен (нет swayosd-client)\n'
    fi
}

case "${1:-}" in
    volume)
        [ -n "${2:-}" ] || usage
        volume "$2"
        ;;
    brightness)
        [ -n "${2:-}" ] || usage
        brightness "$2"
        ;;
    status) status ;;
    *) usage ;;
esac
