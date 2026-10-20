#!/usr/bin/env bash
# screenshot.sh — скриншоты и OCR.
#   screenshot.sh full            весь экран
#   screenshot.sh region          выделенная область
#   screenshot.sh window          активное окно
#   screenshot.sh region edit     область и сразу аннотировать (satty → swappy)
#   screenshot.sh ocr             область → текст в буфер обмена
#
# Снимок кладётся в ~/Pictures/Screenshots, копируется в буфер и показывается
# уведомлением. OCR ничего не сохраняет: временный PNG живёт до конца вызова.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
EDIT=0
[ "${2:-}" = edit ] && EDIT=1

usage() {
    cat >&2 <<'EOF'
usage: screenshot.sh [full|region|window] [edit]
       screenshot.sh ocr
EOF
    exit 1
}

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "$@" >/dev/null 2>&1 || true
}

ocr_langs() {
    local conf="$CONFIG/hypr/ocr.conf" value="rus+eng" line key
    [ -r "$conf" ] || {
        printf '%s\n' "$value"
        return 0
    }
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in '' | '#'*) continue ;; esac
        case "$line" in *=*) ;; *) continue ;; esac
        key="${line%%=*}"
        key="${key//[[:space:]]/}"
        case "${key,,}" in
            langs | ocr_langs)
                value="${line#*=}"
                value="${value#"${value%%[![:space:]]*}"}"
                value="${value%"${value##*[![:space:]]}"}"
                ;;
        esac
    done <"$conf"
    case "$value" in
        '' | *[!A-Za-z0-9_+-]*) value="rus+eng" ;;
    esac
    printf '%s\n' "$value"
}

annotate() {
    local file="$1"
    if command -v satty >/dev/null 2>&1; then
        satty --filename "$file" --output-filename "$file" 2>/dev/null || true
    elif command -v swappy >/dev/null 2>&1; then
        swappy -f "$file" -o "$file" 2>/dev/null || true
    fi
}

ocr() {
    local geom text langs
    command -v tesseract >/dev/null 2>&1 || {
        notify "OCR" "нужен пакет tesseract"
        exit 1
    }
    geom="$(slurp)" || exit 0
    [ -n "$geom" ] || exit 0
    OCR_TMP="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/gothic-ocr.XXXXXX.png")"
    trap 'rm -f "${OCR_TMP:-}"' EXIT
    grim -g "$geom" "$OCR_TMP"
    langs="$(ocr_langs)"
    text="$(tesseract "$OCR_TMP" stdout -l "$langs" 2>/dev/null || true)"
    text="$(printf '%s' "$text" | sed -e 's/[[:space:]]*$//')"
    if [ -z "$text" ]; then
        notify "OCR" "текст не найден"
        return 0
    fi
    printf '%s' "$text" | wl-copy
    notify "OCR" "распознано ${#text} символов"
}

capture() {
    local mode="$1" file geom
    file="$DIR/$(date +%Y-%m-%d_%H-%M-%S).png"
    case "$mode" in
        full)
            mkdir -p "$DIR"
            grim "$file"
            ;;
        region)
            geom="$(slurp)" || exit 0
            [ -n "$geom" ] || exit 0
            mkdir -p "$DIR"
            grim -g "$geom" "$file"
            ;;
        window)
            geom="$(hyprctl activewindow -j 2>/dev/null |
                jq -r 'if .at then "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" else empty end' 2>/dev/null)" || geom=""
            [ -n "$geom" ] || {
                echo "screenshot.sh: нет активного окна" >&2
                exit 1
            }
            mkdir -p "$DIR"
            grim -g "$geom" "$file"
            ;;
        *) usage ;;
    esac
    [ "$EDIT" = 1 ] && annotate "$file"
    wl-copy <"$file"
    notify -i "$file" "Скриншот" "$(basename "$file")"
}

case "${1:-region}" in
    ocr) ocr ;;
    full | region | window) capture "$1" ;;
    *) usage ;;
esac
