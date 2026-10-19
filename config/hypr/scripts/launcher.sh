#!/usr/bin/env bash
# launcher.sh — лаунчер: приложения и режимы поверх одного dmenu.
#   launcher.sh                     приложения (tofi, откат на rofi)
#   launcher.sh apps                то же, явно
#   launcher.sh menu                хаб: режимы и команды (можно печатать «:verb»)
#   launcher.sh files|windows|clipboard|ssh|packages [--list] [запрос]
#   launcher.sh calc [выражение]
#
# Клавиши: SUPER + D / SUPER + Space — приложения, SUPER + Shift + D — хаб.
# Каждый режим печатает строки «метка<TAB>действие»; меню показывает только
# метки, а действие достаёт из той же строки. Команды в хабе не реализованы
# здесь: они уходят в `gothic`, чтобы CLI и лаунчер говорили одним словарём.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
SCRIPTS="$CONFIG/hypr/scripts"
ROFI_THEME="$CONFIG/rofi/settings.rasi"
DMENU="${LAUNCHER_MENU_BIN:-rofi}"
GOTHIC="${LAUNCHER_GOTHIC:-gothic}"
LIMIT="${LAUNCHER_LIMIT:-800}"

usage() {
    cat >&2 <<'EOF'
usage: launcher.sh [apps|menu|files|windows|clipboard|ssh|packages|calc]
       launcher.sh <mode> --list [query]
       launcher.sh calc <expression>
EOF
    exit 2
}

notify() {
    echo "launcher: $*" >&2
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "Лаунчер" "$*" >/dev/null 2>&1 || true
}

dmenu() { # dmenu <prompt>
    "$DMENU" -dmenu -i -p "$1" -theme "$ROFI_THEME"
}

help() {
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
    exit 0
}

# ── Приложения (поведение по умолчанию не менялось) ─────────────────────────
apps() {
    local cfg="${XDG_CACHE_HOME:-$HOME/.cache}/wallust/tofi"
    if command -v tofi-drun >/dev/null 2>&1; then
        if [ -f "$cfg" ]; then
            exec tofi-drun -c "$cfg"
        fi
        exec tofi-drun
    fi
    exec rofi -show drun
}

# ── Провайдеры строк: метка<TAB>действие ────────────────────────────────────
rows_files() {
    local fd_bin
    fd_bin="$(command -v fd 2>/dev/null || command -v fdfind 2>/dev/null || true)"
    [ -n "$fd_bin" ] || return 0
    "$fd_bin" --type f --hidden --exclude .git --max-results "$LIMIT" . "$HOME" 2>/dev/null |
        awk '{ printf "%s\t%s\n", $0, $0 }'
}

rows_windows() {
    command -v hyprctl >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || return 0
    hyprctl clients -j 2>/dev/null |
        jq -r '.[] | select(.mapped == true) | "\(.workspace.id)  \(.class)  \(.title)\t\(.address)"' 2>/dev/null || true
}

rows_clipboard() {
    command -v cliphist >/dev/null 2>&1 || return 0
    cliphist list 2>/dev/null |
        awk -F'\t' '{
            label = $0
            gsub(/\t/, "  ", label)
            if (length(label) > 140) label = substr(label, 1, 140)
            printf "%s\t%s\n", label, $0
        }'
}

rows_ssh() {
    [ -r "$HOME/.ssh/config" ] || return 0
    awk 'tolower($1) == "host" {
            for (i = 2; i <= NF; i++)
                if ($i !~ /[*?!]/) print $i
        }' "$HOME/.ssh/config" | sort -u | awk '{ printf "%s\t%s\n", $0, $0 }'
}

rows_packages() { # rows_packages [query]
    local query="${1:-}"
    if command -v pacman >/dev/null 2>&1; then
        pacman -Ss "$query" 2>/dev/null |
            awk '/^[^[:space:]]+\/[^[:space:]]+ / {
                    name = $1
                    sub(/^[^\/]+\//, "", name)
                    print name "\t" name
                }' | head -n "$LIMIT"
    elif command -v apt-cache >/dev/null 2>&1; then
        apt-cache search "$query" 2>/dev/null |
            awk -F' - ' '{ print $1 "\t" $1 }' | head -n "$LIMIT"
    fi
}

rows_for() { # rows_for <mode> [query]
    case "$1" in
        files) rows_files ;;
        windows) rows_windows ;;
        clipboard) rows_clipboard ;;
        ssh) rows_ssh ;;
        packages) rows_packages "${2:-}" ;;
        *) return 1 ;;
    esac
}

prompt_for() {
    case "$1" in
        files) echo "Файлы" ;;
        windows) echo "Окна" ;;
        clipboard) echo "Буфер" ;;
        ssh) echo "SSH" ;;
        packages) echo "Пакет" ;;
        *) echo "gothic" ;;
    esac
}

# ── Действия режимов ────────────────────────────────────────────────────────
act() { # act <mode> <payload>
    case "$1" in
        files)
            if command -v xdg-open >/dev/null 2>&1; then
                setsid xdg-open "$2" >/dev/null 2>&1 &
            else
                exec "$SCRIPTS/run-in-terminal.sh" yazi "$(dirname "$2")"
            fi
            ;;
        windows)
            command -v hyprctl >/dev/null 2>&1 || {
                notify "hyprctl не найден"
                return 0
            }
            hyprctl dispatch focuswindow "address:$2" >/dev/null 2>&1 || true
            ;;
        clipboard)
            printf '%s' "$2" | cliphist decode | wl-copy
            ;;
        ssh)
            [ -n "$2" ] || return 0
            setsid "$SCRIPTS/run-in-terminal.sh" ssh "$2" >/dev/null 2>&1 &
            ;;
        packages)
            [ -n "$2" ] || return 0
            if command -v pacman >/dev/null 2>&1; then
                exec "$SCRIPTS/run-in-terminal.sh" sudo pacman -S --needed "$2"
            elif command -v apt-get >/dev/null 2>&1; then
                exec "$SCRIPTS/run-in-terminal.sh" sudo apt-get install "$2"
            else
                notify "нет пакетного менеджера"
            fi
            ;;
        *) return 1 ;;
    esac
}

# ── Режим: выбор строки и действие ──────────────────────────────────────────
run_mode() { # run_mode <mode> [--list] [query]
    local mode="$1" flag="${2:-}" query="${3:-}" rows labels choice payload

    if [ "$mode" = packages ] && [ "$flag" != --list ] && [ -z "$query" ]; then
        query="$(printf '' | dmenu "Пакеты:")" || exit 0
        [ -n "$query" ] || exit 0
    fi

    rows="$(rows_for "$mode" "$query")" || {
        notify "неизвестный режим: $mode"
        return 2
    }
    labels="$(printf '%s\n' "$rows" | cut -f1 | sed '/^$/d')"

    if [ -z "$labels" ]; then
        if [ "$flag" = --list ]; then
            return 0
        fi
        notify "режим «$mode» пуст — нет данных или не установлен инструмент"
        return 0
    fi

    if [ "$flag" = --list ]; then
        printf '%s\n' "$labels"
        return 0
    fi

    choice="$(printf '%s\n' "$labels" | dmenu "$(prompt_for "$mode")")" || exit 0
    [ -n "$choice" ] || exit 0
    payload="$(printf '%s\n' "$rows" |
        awk -v want="$choice" 'BEGIN { FS = "\t" } $1 == want { print substr($0, index($0, "\t") + 1); exit }')"
    if [ -n "$payload" ]; then
        act "$mode" "$payload"
    fi
    return 0
}

# ── Калькулятор ─────────────────────────────────────────────────────────────
calc() {
    local expr="${1:-}" out bad
    if [ -z "$expr" ]; then
        expr="$(printf '' | dmenu "=")" || exit 0
    fi
    [ -n "$expr" ] || exit 0

    # В awk уходит текст выражения, поэтому сначала выбрасываем всё, кроме
    # цифр, пробелов и арифметики: иначе это была бы инъекция в программу awk.
    bad="$(printf '%s' "$expr" | tr -d '0-9+*/%^().[:space:]-')"
    if [ -n "$bad" ]; then
        echo "launcher: только цифры и + - * / % ^ ( ) ." >&2
        return 2
    fi

    out="$(awk "BEGIN { printf \"%.10g\\n\", $expr }" 2>/dev/null)" || {
        echo "launcher: не выражение: $expr" >&2
        return 2
    }
    printf '%s\n' "$out"
    if command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$out" | wl-copy || true
    fi
    notify "$expr = $out"
}

# ── Хаб: режимы и команды ───────────────────────────────────────────────────
hub_rows() {
    cat <<'EOF'
Приложения
Файлы
Окна
Буфер обмена
SSH
Калькулятор
Пакеты
Тема: готика
Тема: светлая
Тема: из обоев
Сессия: сохранить
Сессия: восстановить
Переключатели
Записать экран
Остановить запись
Клавиши
Настройки
Доктор
EOF
}

# run_verb <text> — «:theme light» и подобное: единственная реализация команд
# живёт в gothic, лаунчер только передаёт слова.
run_verb() {
    local text="$1" verb rest
    local -a args=()
    verb="${text%% *}"
    rest="${text#"$verb"}"
    rest="${rest# }"
    read -r -a args <<<"$rest" || true
    case "$verb" in
        theme | session | toggle | wall | record | keybinds | settings | doctor)
            "$GOTHIC" "$verb" "${args[@]}"
            ;;
        *)
            notify "неизвестная команда «$verb» (gothic help)"
            ;;
    esac
}

hub() {
    local choice name
    choice="$(hub_rows | dmenu "gothic")" || exit 0
    [ -n "$choice" ] || exit 0

    case "$choice" in
        :*) run_verb "${choice#:}" ;;
        "Приложения") apps ;;
        "Файлы") run_mode files ;;
        "Окна") run_mode windows ;;
        "Буфер обмена") run_mode clipboard ;;
        "SSH") run_mode ssh ;;
        "Калькулятор") calc ;;
        "Пакеты") run_mode packages ;;
        "Тема: готика") "$GOTHIC" theme dark ;;
        "Тема: светлая") "$GOTHIC" theme light ;;
        "Тема: из обоев") "$GOTHIC" theme dynamic ;;
        "Сессия: сохранить")
            name="$(printf '%s\n' "session-$(date +%Y-%m-%d)" | dmenu "Имя сессии")" || exit 0
            if [ -n "$name" ]; then
                "$GOTHIC" session save "$name"
            fi
            ;;
        "Сессия: восстановить") "$GOTHIC" session menu ;;
        "Переключатели") exec "$SCRIPTS/quick.sh" ;;
        "Записать экран") "$GOTHIC" record start full audio ;;
        "Остановить запись") "$GOTHIC" record stop ;;
        "Клавиши") exec "$SCRIPTS/keybinds.sh" ;;
        "Настройки") exec "$SCRIPTS/settings.sh" ;;
        "Доктор") "$GOTHIC" doctor ;;
        *) return 0 ;;
    esac
}

main() {
    local mode="${1:-}"
    case "$mode" in
        "" | apps) apps ;;
        menu) hub ;;
        files | windows | clipboard | ssh | packages)
            shift
            run_mode "$mode" "$@"
            ;;
        calc)
            shift
            calc "$@"
            ;;
        help | -h | --help) help ;;
        *) usage ;;
    esac
}

main "$@"
