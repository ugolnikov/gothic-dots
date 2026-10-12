#!/usr/bin/env bash
# settings.sh — лёгкий центр настроек рабочего стола на rofi (готик).
# Клавиша: SUPER + ,
# Выборы, которые можно менять на лету: тема (готика/обои), обои (статика/
# анимация/градиент), терминал, SHELL, система уведомлений.

set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
ROFI_THEME="$CONFIG/rofi/settings.rasi"
SCRIPTS="$CONFIG/hypr/scripts"
BINDS="$CONFIG/hypr/conf.d/binds.conf"
STATE="$CONFIG/hypr"
DYNAMIC="$STATE/dynamic-theme"
TERMFILE="$STATE/terminal"
NOTIFILE="$STATE/notifications"

pick() { rofi -dmenu -i -p "$1" -theme "$ROFI_THEME"; }
note() { notify-send "Настройки" "$1" 2>/dev/null || true; }
cur() { cat "$STATE/$1" 2>/dev/null || echo "$2"; }
radio() { # radio <current> <items...>
    local c="$1"
    shift
    local i
    for i in "$@"; do
        if [ "$i" = "$c" ]; then echo "● $i"; else echo "○ $i"; fi
    done
}

theme_label() {
    if [ -e "$DYNAMIC" ]; then echo "Тема: палитра из обоев"; else echo "Тема: готика (фикс.)"; fi
}

toggle_theme() {
    if [ -e "$DYNAMIC" ]; then
        rm -f "$DYNAMIC"
        note "Готик-палитра"
    else
        # Палитра из обоев и светлая тема делят одни файлы — включаем одну.
        rm -f "$STATE/light-theme"
        touch "$DYNAMIC"
        note "Палитра из обоев"
    fi
    "$SCRIPTS/theme.sh" >/dev/null 2>&1 || true
}

light_state() {
    if [ -e "$STATE/light-theme" ]; then echo "вкл"; else echo "выкл"; fi
}

toggle_light() {
    "$SCRIPTS/theme-mode.sh" toggle >/dev/null 2>&1 || true
    note "Светлая тема: $(light_state)"
}

random_state() {
    if [ -e "$STATE/random-wallpaper" ]; then echo "вкл"; else echo "выкл"; fi
}

toggle_random() {
    if [ -e "$STATE/random-wallpaper" ]; then
        rm -f "$STATE/random-wallpaper"
        note "Случайные обои: выкл"
    else
        touch "$STATE/random-wallpaper"
        note "Случайные обои: вкл (со следующего входа)"
    fi
}

choose_wallpaper() {
    local c
    c="$(printf '%s\n' "Статичные обои" "Анимированные (GIF/видео)" "Градиент" | pick "Обои")" || return 0
    case "$c" in
        "Статичные обои") PICKER_FILTER=image "$SCRIPTS/wallpaper-picker.sh" ;;
        Анимированные*) PICKER_FILTER=video "$SCRIPTS/wallpaper-picker.sh" ;;
        "Градиент") "$SCRIPTS/wallpaper.sh" ;;
    esac
}

choose_terminal() {
    local c
    c="$(radio "$(cur terminal foot)" foot kitty alacritty | pick "Терминал")" || return 0
    c="${c#* }"
    echo "$c" >"$TERMFILE"
    note "Терминал: $c"
}

choose_shell() {
    local c path
    c="$(radio "${SHELL##*/}" fish bash | pick "SHELL (логин)")" || return 0
    c="${c#* }"
    path="$(command -v "$c" 2>/dev/null || true)"
    [ -n "$path" ] || {
        note "Не найден: $c"
        return 0
    }
    grep -qx "$path" /etc/shells 2>/dev/null || echo "$path" | sudo tee -a /etc/shells >/dev/null 2>&1 || true
    "$SCRIPTS/run-in-terminal.sh" chsh -s "$path" >/dev/null 2>&1 &
    note "SHELL → $c (подтверди пароль в терминале)"
}

choose_notifications() {
    local c
    c="$(radio "$(cur notifications mako)" mako swaync | pick "Уведомления")" || return 0
    c="${c#* }"
    echo "$c" >"$NOTIFILE"
    "$SCRIPTS/notifications.sh" >/dev/null 2>&1 &
    note "Уведомления: $c"
}

restart_bar() {
    pkill -x waybar 2>/dev/null || true
    sleep 0.2
    setsid waybar >/dev/null 2>&1 &
    note "Панель перезапущена"
}

show_monitors() {
    local out
    out="$(hyprctl monitors -j 2>/dev/null \
        | jq -r '.[] | "\(.name)  \(.width)x\(.height)@\(.refreshRate | floor)  scale \(.scale)"' 2>/dev/null)" || out=""
    [ -n "$out" ] || out="hyprctl недоступен"
    printf '%s\n' "$out" | rofi -dmenu -i -p "Мониторы" -theme "$ROFI_THEME" >/dev/null || true
}

show_binds() {
    [ -f "$BINDS" ] || {
        note "binds.conf не найден"
        return 0
    }
    # shellcheck disable=SC2016  # sed must see the literal $mod, not a shell expansion
    grep -E '^[[:space:]]*bind' "$BINDS" \
        | sed -E 's/^[[:space:]]*bind[a-z]*[[:space:]]*=[[:space:]]*//; s/\$mod/SUPER/g; s/[[:space:]]*,[[:space:]]*/ | /g' \
        | rofi -dmenu -i -p "Клавиши" -theme "$ROFI_THEME" >/dev/null || true
}

anim_state() {
    if [ -f "$CONFIG/hypr/conf.d/animations.dynamic.conf" ] \
        && grep -q 'true' "$CONFIG/hypr/conf.d/animations.dynamic.conf"; then
        echo "вкл"
    else
        echo "выкл"
    fi
}

choose_layout() {
    local c
    c="$(radio "$(cur layout dwindle)" dwindle master scrolling | pick "Раскладка")" || return 0
    c="${c#* }"
    echo "$c" >"$STATE/layout"
    printf 'general { layout = %s }\n' "$c" >"$CONFIG/hypr/conf.d/layout.dynamic.conf"
    hyprctl keyword general:layout "$c" >/dev/null 2>&1 || hyprctl reload >/dev/null 2>&1 || true
    note "Раскладка: $c"
}

toggle_animations() {
    local c en
    c="$(radio "$(anim_state)" выкл вкл | pick "Анимации")" || return 0
    c="${c#* }"
    if [ "$c" = "вкл" ]; then en=true; else en=false; fi
    printf 'animations { enabled = %s }\n' "$en" >"$CONFIG/hypr/conf.d/animations.dynamic.conf"
    hyprctl keyword animations:enabled "$en" >/dev/null 2>&1 || hyprctl reload >/dev/null 2>&1 || true
    note "Анимации: $c"
}

open_qt() {
    if command -v qt6ct >/dev/null 2>&1; then qt6ct
    else note "qt6ct не установлен"; fi
}

reload() {
    hyprctl reload >/dev/null 2>&1 || true
    note "Конфиг перезагружен"
}

main() {
    local choice
    choice="$(printf '%s\n' \
        "Обои" \
        "$(theme_label)" \
        "Терминал: $(cur terminal foot)" \
        "SHELL: ${SHELL##*/}" \
        "Уведомления: $(cur notifications mako)" \
        "Раскладка: $(cur layout dwindle)" \
        "Анимации: $(anim_state)" \
        "Светлая тема: $(light_state)" \
        "Случайные обои: $(random_state)" \
        "Панель — перезапуск" \
        "Мониторы" \
        "Клавиши" \
        "Qt-тема (qt6ct)" \
        "Перезагрузить конфиг" \
        "Питание" \
        | pick "Настройки")" || exit 0

    case "$choice" in
        "Обои") choose_wallpaper ;;
        Тема:*) toggle_theme ;;
        Терминал:*) choose_terminal ;;
        SHELL:*) choose_shell ;;
        Уведомления:*) choose_notifications ;;
        Раскладка:*) choose_layout ;;
        Анимации:*) toggle_animations ;;
        "Светлая тема:"*) toggle_light ;;
        "Случайные обои:"*) toggle_random ;;
        "Панель — перезапуск") restart_bar ;;
        "Мониторы") show_monitors ;;
        "Клавиши") show_binds ;;
        "Qt-тема (qt6ct)") open_qt ;;
        "Перезагрузить конфиг") reload ;;
        "Питание") "$SCRIPTS/powermenu.sh" ;;
        *) exit 0 ;;
    esac
}

main
