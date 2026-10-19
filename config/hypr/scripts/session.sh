#!/usr/bin/env bash
# session.sh — снимок рабочих пространств: какие окна и где стоят.
#   session.sh save <name>                  снять текущее расположение окон
#   session.sh restore <name> [--dry-run]   вернуть окна (только двигает и запускает)
#   session.sh list                         что сохранено
#   session.sh show <name>                  что внутри снимка
#   session.sh delete <name>                удалить снимок
#   session.sh menu                         rofi-меню (SUPER + Shift + M)
#
# Снимок — JSON в ~/.config/hypr/sessions/<name>.json (права 600, вне git).
# restore ничего не закрывает: совпавшие по классу окна переносятся на свои
# рабочие пространства (с плавающим положением, размером, пином и fullscreen),
# а отсутствующие приложения запускаются ровно тем argv, с каким работали, и
# ждут появления окна (SESSION_WAIT секунд). Команды берутся из /proc, а не из
# shell-строки, поэтому запуск идёт без eval.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DIR="$CONFIG/hypr/sessions"

# Переопределяемо: тесты подставляют свой hyprctl, /proc и rofi.
HYPRCTL="${SESSION_HYPRCTL:-hyprctl}"
PROC="${SESSION_PROC:-/proc}"
WAIT="${SESSION_WAIT:-12}"
POLL="${SESSION_POLL:-0.3}"
ROFI_THEME="${SESSION_ROFI_THEME:-$CONFIG/rofi/settings.rasi}"

DRY=0

usage() {
    cat >&2 <<'EOF'
usage: session.sh save <name>
       session.sh restore <name> [--dry-run]
       session.sh list | show <name> | delete <name> | menu
EOF
    exit 2
}

die() {
    echo "session.sh: $*" >&2
    exit 2
}

note() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "Сессия" "$1" >/dev/null 2>&1 || true
    return 0
}

require_hyprctl() {
    command -v "$HYPRCTL" >/dev/null 2>&1 ||
        die "hyprctl не найден — сессии работают только в Hyprland"
}

# valid_name <name> — имя становится именем файла, поэтому только буквы,
# цифры, «_» и «-», до 32 символов.
valid_name() {
    case "${1:-}" in
        '' | *[!A-Za-z0-9_-]*) return 1 ;;
    esac
    [ "${#1}" -le 32 ]
}

session_file() {
    printf '%s/%s.json\n' "$DIR" "$1"
}

clients() {
    "$HYPRCTL" clients -j
}

# ── Снимок ──────────────────────────────────────────────────────────────────
# cmdline_json <pid> — argv процесса как JSON-массив, без разбора shell-строки:
# аргументы с пробелами и кавычками переживают снимок без искажений.
cmdline_json() {
    local pid="${1:-}" path
    path="$PROC/$pid/cmdline"
    if [ -z "$pid" ] || [ "$pid" = 0 ] || [ ! -r "$path" ]; then
        printf '[]'
        return 0
    fi
    tr '\0' '\n' <"$path" | jq -R -s 'split("\n") | map(select(length > 0))'
}

cwd_of() {
    local pid="${1:-}"
    [ -n "$pid" ] || return 0
    readlink "$PROC/$pid/cwd" 2>/dev/null || true
}

save_session() {
    local name="${1:-}" file tmp pid
    valid_name "$name" ||
        die "имя сессии: буквы, цифры, «_» и «-», до 32 символов; получено '$name'"
    require_hyprctl
    mkdir -p "$DIR"
    file="$(session_file "$name")"
    tmp="$(mktemp "$DIR/.$name.XXXXXX")"

    # Специальные рабочие пространства сохраняются именем (special:имя),
    # обычные — номером: dispatcher принимает и то, и другое.
    clients |
        jq -c '.[] | select(.mapped == true) | {
                class: (.class // ""),
                title: (.title // ""),
                ws: (if ((.workspace.name // "") | startswith("special:")) then .workspace.name else (.workspace.id | tostring) end),
                floating: (.floating // false),
                pinned: (.pinned // false),
                fullscreen: (.fullscreen // 0),
                at: (.at // [0, 0]),
                size: (.size // [0, 0]),
                pid: (.pid // 0)
            }' |
        while IFS= read -r entry; do
            pid="$(jq -r '.pid' <<<"$entry")"
            jq -c --argjson cmd "$(cmdline_json "$pid")" --arg cwd "$(cwd_of "$pid")" \
                '. + {cmd: $cmd, cwd: $cwd}' <<<"$entry"
        done |
        jq -s --arg name "$name" --arg saved "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{version: 1, name: $name, saved: $saved, clients: .}' >"$tmp"

    chmod 600 "$tmp"
    mv -f "$tmp" "$file"
    if [ "$name" != last ]; then
        cp -f "$file" "$(session_file last)"
        chmod 600 "$(session_file last)"
    fi
    printf 'session.sh: сессия «%s» сохранена — окон %s\n' \
        "$name" "$(jq '.clients | length' "$file")"
}

# ── Возврат ─────────────────────────────────────────────────────────────────
# append_unique <json array> <value>
append_unique() {
    jq -c --arg v "$2" '. + [$v] | unique' <<<"$1"
}

# find_match <state> <entry> <used> — адрес живого окна того же класса,
# которое ещё не занято другой записью снимка. Заголовок — уточнение, не
# требование: у браузеров он меняется.
find_match() {
    jq -r --argjson entry "$2" --argjson used "$3" '
        [ .[] | select(.mapped == true)
              | select((.class // "") == $entry.class)
              | select((.address as $a | $used | index($a)) == null) ]
        | (map(select(.title == $entry.title)) + .)
        | (.[0].address // empty)
    ' <<<"$1"
}

dispatch() {
    if [ "$DRY" = 1 ]; then
        printf '  hyprctl dispatch %s\n' "$*"
    else
        "$HYPRCTL" dispatch "$@" >/dev/null
    fi
}

# focus_and <address> <dispatcher> [args...] — часть dispatcher'ов работает
# только над активным окном; после применения возвращаем фокус обратно.
focus_and() {
    local addr="$1" prev
    shift
    if [ "$DRY" = 1 ]; then
        printf '  hyprctl dispatch focuswindow address:%s → %s\n' "$addr" "$*"
        return 0
    fi
    prev="$("$HYPRCTL" activewindow -j 2>/dev/null | jq -r '.address // ""' 2>/dev/null || true)"
    "$HYPRCTL" dispatch focuswindow "address:$addr" >/dev/null
    "$HYPRCTL" dispatch "$@" >/dev/null
    if [ -n "$prev" ] && [ "$prev" != "$addr" ]; then
        "$HYPRCTL" dispatch focuswindow "address:$prev" >/dev/null
    fi
}

# launch_entry <entry> — запустить приложение сохранённым argv в сохранённом
# каталоге. Новая сессия процессов, чтобы приложение пережило этот скрипт.
launch_entry() {
    local entry="$1" cwd
    local cmd=()
    cwd="$(jq -r '.cwd // ""' <<<"$entry")"
    mapfile -t cmd < <(jq -r '.cmd[]' <<<"$entry")
    [ "${#cmd[@]}" -gt 0 ] || return 1
    if [ "$DRY" = 1 ]; then
        printf '  запуск: %s\n' "$(printf '%q ' "${cmd[@]}")"
        [ -n "$cwd" ] && printf '    cwd: %s\n' "$cwd"
        return 0
    fi
    (
        if [ -n "$cwd" ] && [ -d "$cwd" ]; then cd "$cwd" || true; fi
        setsid "${cmd[@]}" >/dev/null 2>&1 &
    )
    return 0
}

# apply_entry <entry> <address> <state> — вернуть окно на его место.
apply_entry() {
    local entry="$1" addr="$2" state="$3"
    local cur ws floating pinned fs cur_float cur_pin cur_fs x y w h

    cur="$(jq -c --arg a "$addr" '.[] | select(.address == $a)' <<<"$state")"
    [ -n "$cur" ] || return 0

    ws="$(jq -r '.ws' <<<"$entry")"
    floating="$(jq -r '.floating' <<<"$entry")"
    pinned="$(jq -r '.pinned' <<<"$entry")"
    fs="$(jq -r '.fullscreen' <<<"$entry")"
    cur_float="$(jq -r '.floating // false' <<<"$cur")"
    cur_pin="$(jq -r '.pinned // false' <<<"$cur")"
    cur_fs="$(jq -r '.fullscreen // 0' <<<"$cur")"

    dispatch movetoworkspacesilent "$ws,address:$addr"

    if [ "$floating" = true ] && [ "$cur_float" != true ]; then
        dispatch setfloating "address:$addr"
    elif [ "$floating" != true ] && [ "$cur_float" = true ]; then
        dispatch settiled "address:$addr"
    fi

    if [ "$floating" = true ]; then
        x="$(jq -r '.at[0]' <<<"$entry")"
        y="$(jq -r '.at[1]' <<<"$entry")"
        w="$(jq -r '.size[0]' <<<"$entry")"
        h="$(jq -r '.size[1]' <<<"$entry")"
        dispatch movewindowpixel "exact $x $y,address:$addr"
        dispatch resizewindowpixel "exact $w $h,address:$addr"
    fi

    if [ "$pinned" = true ] && [ "$cur_pin" != true ]; then
        dispatch pin "address:$addr"
    elif [ "$pinned" != true ] && [ "$cur_pin" = true ]; then
        dispatch pin "address:$addr"
    fi

    if [ "$fs" != "$cur_fs" ]; then
        focus_and "$addr" fullscreenstate "$fs" -1
    fi
}

restore_session() {
    local name="${1:-}" file state total i entry addr
    valid_name "$name" || die "имя сессии: буквы, цифры, «_» и «-»"
    file="$(session_file "$name")"
    [ -r "$file" ] || die "нет снимка «$name» — список: session.sh list"
    require_hyprctl

    total="$(jq '.clients | length' "$file")"
    if [ "$total" -eq 0 ]; then
        printf 'session.sh: снимок «%s» пуст\n' "$name"
        return 0
    fi

    state="$(clients)"
    local -a addrs=() pending=()
    local -A launched_cmds=()
    local used='[]' key
    local moved=0 launched=0 missing=0

    # 1. Что уже открыто — сразу получает адрес.
    for ((i = 0; i < total; i++)); do
        entry="$(jq -c ".clients[$i]" "$file")"
        addr="$(find_match "$state" "$entry" "$used")"
        if [ -n "$addr" ]; then
            addrs[$i]="$addr"
            used="$(append_unique "$used" "$addr")"
        fi
    done

    # 2. Чего не хватает — запускаем, повторяя команду один раз на снимок.
    for ((i = 0; i < total; i++)); do
        [ -z "${addrs[$i]:-}" ] || continue
        entry="$(jq -c ".clients[$i]" "$file")"
        key="$(jq -c '.cmd' <<<"$entry")"
        if [ "$(jq 'length' <<<"$key")" -eq 0 ]; then
            # Запускать нечего: запись останется неразмещённой и попадёт в
            # итоговый счётчик на шаге 4 (считать здесь значило бы дважды).
            printf '  не запустить (нет команды): %s\n' "$(jq -r '.class' <<<"$entry")" >&2
            continue
        fi
        pending+=("$i")
        if [ -n "${launched_cmds[$key]:-}" ]; then
            continue
        fi
        launched_cmds[$key]=1
        launch_entry "$entry"
        launched=$((launched + 1))
    done

    # 3. Ждём окна запущенных приложений и раздаём им адреса.
    if [ "$DRY" = 0 ] && [ "${#pending[@]}" -gt 0 ]; then
        local deadline waiting
        deadline=$((SECONDS + WAIT))
        while [ "$SECONDS" -lt "$deadline" ]; do
            waiting=0
            state="$(clients)"
            for i in "${pending[@]}"; do
                [ -z "${addrs[$i]:-}" ] || continue
                entry="$(jq -c ".clients[$i]" "$file")"
                addr="$(find_match "$state" "$entry" "$used")"
                if [ -n "$addr" ]; then
                    addrs[$i]="$addr"
                    used="$(append_unique "$used" "$addr")"
                else
                    waiting=1
                fi
            done
            [ "$waiting" = 1 ] || break
            sleep "$POLL"
        done
    fi

    # 4. Возвращаем окна на места.
    for ((i = 0; i < total; i++)); do
        entry="$(jq -c ".clients[$i]" "$file")"
        addr="${addrs[$i]:-}"
        if [ -z "$addr" ]; then
            [ "$DRY" = 1 ] && continue
            missing=$((missing + 1))
            continue
        fi
        apply_entry "$entry" "$addr" "$state"
        moved=$((moved + 1))
    done

    if [ "$DRY" = 1 ]; then
        printf 'session.sh: план для «%s» — окон %s, запусков %s (ничего не изменено)\n' \
            "$name" "$total" "$launched"
    else
        printf 'session.sh: сессия «%s» — окон %s, запущено %s, не найдено %s\n' \
            "$name" "$moved" "$launched" "$missing"
    fi
    note "Сессия «$name»: окон $moved, запущено $launched"
}

# ── Список, показ, удаление ─────────────────────────────────────────────────
list_names() {
    [ -d "$DIR" ] || return 0
    # last.json — копия последнего снимка для `restore last`; в списке она не
    # нужна, иначе каждая сессия показывалась бы дважды.
    find "$DIR" -maxdepth 1 -type f -name '*.json' ! -name 'last.json' -printf '%f\n' 2>/dev/null |
        sed 's/\.json$//' | sort
}

list_sessions() {
    local name file
    [ -d "$DIR" ] || {
        printf 'session.sh: снимков нет\n'
        return 0
    }
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        file="$(session_file "$name")"
        printf '%-24s %3s окон  %s\n' "$name" \
            "$(jq '.clients | length' "$file")" "$(jq -r '.saved' "$file")"
    done < <(list_names)
}

show_session() {
    local name="${1:-}" file
    valid_name "$name" || die "имя сессии: буквы, цифры, «_» и «-»"
    file="$(session_file "$name")"
    [ -r "$file" ] || die "нет снимка «$name»"
    printf 'session.sh: «%s», снят %s, окон %s\n' "$name" \
        "$(jq -r '.saved' "$file")" "$(jq '.clients | length' "$file")"
    jq -r '.clients[] | [.ws, (if .floating then "float" else "tile" end), .class, .title, ((.cmd // []) | join(" "))] | @tsv' "$file" |
        while IFS=$'\t' read -r ws kind class title cmd; do
            printf '  ws %-10s %-5s %-20s %s' "$ws" "$kind" "$class" "$title"
            [ -n "$cmd" ] && printf ' ← %s' "$cmd"
            printf '\n'
        done
}

delete_session() {
    local name="${1:-}" file
    valid_name "$name" || die "имя сессии: буквы, цифры, «_» и «-»"
    file="$(session_file "$name")"
    [ -e "$file" ] || die "нет снимка «$name»"
    rm -f "$file"
    printf 'session.sh: снимок «%s» удалён\n' "$name"
}

# ── Меню ────────────────────────────────────────────────────────────────────
menu() {
    command -v rofi >/dev/null 2>&1 || die "rofi не установлен"
    local action pick name
    action="$(printf '%s\n' \
        "Сохранить текущую сессию" \
        "Восстановить сессию" \
        "Показать сессию" \
        "Удалить сессию" |
        rofi -dmenu -i -p "Сессия" -theme "$ROFI_THEME")" || exit 0
    [ -n "$action" ] || exit 0

    case "$action" in
        "Сохранить текущую сессию")
            name="$(printf '%s\n' "session-$(date +%Y-%m-%d)" |
                rofi -dmenu -p "Имя сессии" -theme "$ROFI_THEME")" || exit 0
            [ -n "$name" ] && save_session "$name"
            ;;
        "Восстановить сессию")
            pick="$(list_names | rofi -dmenu -i -p "Восстановить" -theme "$ROFI_THEME")" || exit 0
            [ -n "$pick" ] && restore_session "$pick"
            ;;
        "Показать сессию")
            pick="$(list_names | rofi -dmenu -i -p "Показать" -theme "$ROFI_THEME")" || exit 0
            [ -n "$pick" ] && show_session "$pick"
            ;;
        "Удалить сессию")
            pick="$(list_names | rofi -dmenu -i -p "Удалить" -theme "$ROFI_THEME")" || exit 0
            [ -n "$pick" ] && delete_session "$pick"
            ;;
        *) exit 0 ;;
    esac
}

main() {
    case "${1:-}" in
        save) save_session "${2:-}" ;;
        restore)
            [ "${3:-}" = --dry-run ] && DRY=1
            restore_session "${2:-}"
            ;;
        list) list_sessions ;;
        show) show_session "${2:-}" ;;
        delete) delete_session "${2:-}" ;;
        menu) menu ;;
        *) usage ;;
    esac
}

main "$@"
