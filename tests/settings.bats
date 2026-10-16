#!/usr/bin/env bats
# Tests for the settings center (config/hypr/scripts/settings.sh). Run with:
#
#   bats tests/
#
# The settings center reports the palette mode by querying the module
# (palette.sh status) and drives its theme rows through the module, so it never
# inspects the marker files itself. These tests drive it against a throwaway
# config tree with rofi and the reload consumers stubbed on PATH.

load helpers

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SETTINGS="$REPO_ROOT/config/hypr/scripts/settings.sh"
    SCRIPTS="$REPO_ROOT/config/hypr/scripts"

    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
    mkdir -p "$XDG_CONFIG_HOME/hypr/scripts" "$XDG_CACHE_HOME"

    # settings.sh resolves the palette module and the theme-mode shim through
    # $XDG_CONFIG_HOME/hypr/scripts. Link the real ones there so the run
    # exercises the true delegation seam.
    ln -s "$SCRIPTS/palette.sh" "$XDG_CONFIG_HOME/hypr/scripts/palette.sh"
    ln -s "$SCRIPTS/theme-mode.sh" "$XDG_CONFIG_HOME/hypr/scripts/theme-mode.sh"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    ROFI_LOG="$BATS_TEST_TMPDIR/rofi.log"
    export CALLS ROFI_LOG
    export PATH="$STUB_BIN:$PATH"

    # rofi records the menu it was handed and, when ROFI_CHOICE names a row,
    # returns that row as the pick — so a test can drive a single action. With
    # no ROFI_CHOICE the pick is empty and the settings center just exits.
    cat >"$STUB_BIN/rofi" <<'EOF'
#!/usr/bin/env bash
input="$(cat)"
printf '%s\n' "$input" >>"$ROFI_LOG"
if [ -n "${ROFI_CHOICE:-}" ]; then
    printf '%s\n' "$input" | grep -m1 -- "$ROFI_CHOICE" || true
fi
EOF
    chmod +x "$STUB_BIN/rofi"

    for tool in hyprctl pkill swaync-client notify-send; do
        cat >"$STUB_BIN/$tool" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$tool \$*" >>"\$CALLS"
EOF
        chmod +x "$STUB_BIN/$tool"
    done

    stub_wallust
}

# run_menu — run the settings center once with no pick (rofi returns nothing)
# and print the menu rows it offered.
run_menu() {
    "$SETTINGS" >/dev/null 2>&1 || true
    cat "$ROFI_LOG" 2>/dev/null || true
}

# record_theme_mode — replace the theme-mode shim with a recorder, so a test can
# observe that the light/dark row was routed through it.
record_theme_mode() {
    rm -f "$XDG_CONFIG_HOME/hypr/scripts/theme-mode.sh"
    cat >"$XDG_CONFIG_HOME/hypr/scripts/theme-mode.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "theme-mode $*" >>"$CALLS"
EOF
    chmod +x "$XDG_CONFIG_HOME/hypr/scripts/theme-mode.sh"
}

# record_keybinds — replace the cheatsheet with a recorder, so a test can
# observe that the keybind row was routed to keybinds.sh.
record_keybinds() {
    cat >"$XDG_CONFIG_HOME/hypr/scripts/keybinds.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "keybinds" >>"$CALLS"
EOF
    chmod +x "$XDG_CONFIG_HOME/hypr/scripts/keybinds.sh"
}

# --- the state rows track the module's status query ---

@test "the settings rows report gothic and light off in dark mode" {
    printf 'dark\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"

    run run_menu
    [[ "$output" == *"Тема: готика (фикс.)"* ]]
    [[ "$output" == *"Светлая тема: выкл"* ]]
}

@test "the settings rows report light on when the module is light" {
    printf 'light\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"

    run run_menu
    [[ "$output" == *"Светлая тема: вкл"* ]]
    [[ "$output" == *"Тема: готика (фикс.)"* ]]
}

@test "the settings rows report the wallpaper-derived mode when the module is dynamic" {
    printf 'dynamic\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"

    run run_menu
    [[ "$output" == *"Тема: палитра из обоев"* ]]
    [[ "$output" == *"Светлая тема: выкл"* ]]
}

# The module's status wins over a stray legacy marker: if the settings center
# queried that marker itself it would report light on here.
@test "the settings rows follow the module, not a stray legacy marker" {
    printf 'dynamic\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"
    : >"$XDG_CONFIG_HOME/hypr/light-theme"

    run run_menu
    [[ "$output" == *"Тема: палитра из обоев"* ]]
    [[ "$output" == *"Светлая тема: выкл"* ]]
}

@test "the settings rows follow the module's migration of a legacy marker" {
    : >"$XDG_CONFIG_HOME/hypr/light-theme"

    run run_menu
    [[ "$output" == *"Светлая тема: вкл"* ]]
}

# --- the theme rows act through the module ---

@test "the theme row turns the wallpaper-derived mode on from dark" {
    printf 'dark\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"
    export ROFI_CHOICE='^Тема:'

    run "$SETTINGS"
    [ "$status" -eq 0 ]
    [ "$(cat "$XDG_CONFIG_HOME/hypr/palette-mode")" = dynamic ]
    grep -qx 'hyprctl reload' "$CALLS"
}

@test "the theme row turns the wallpaper-derived mode off again" {
    printf 'dynamic\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"
    export ROFI_CHOICE='^Тема:'

    run "$SETTINGS"
    [ "$status" -eq 0 ]
    [ "$(cat "$XDG_CONFIG_HOME/hypr/palette-mode")" = dark ]
}

@test "the light row turns light on through the module" {
    printf 'dark\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"
    export ROFI_CHOICE='^Светлая тема:'

    run "$SETTINGS"
    [ "$status" -eq 0 ]
    [ "$(cat "$XDG_CONFIG_HOME/hypr/palette-mode")" = light ]
    grep -q '#f2efe7' "$XDG_CONFIG_HOME/waybar/colors.dynamic.css"
}

@test "the light row turns light off through the module" {
    printf 'light\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"
    export ROFI_CHOICE='^Светлая тема:'

    run "$SETTINGS"
    [ "$status" -eq 0 ]
    [ "$(cat "$XDG_CONFIG_HOME/hypr/palette-mode")" = dark ]
}

# #10 acceptance: the light/dark row must go through the theme-mode shim, not
# call the module directly.
@test "the light row routes through the theme-mode entry point" {
    printf 'dark\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"
    export ROFI_CHOICE='^Светлая тема:'
    record_theme_mode

    run "$SETTINGS"
    [ "$status" -eq 0 ]
    grep -qx 'theme-mode light' "$CALLS"
}

# The wallpaper (dynamic) row deliberately stays on the module: no entry point
# sets the dynamic mode.
@test "the wallpaper row calls the module, not the theme-mode entry point" {
    printf 'dark\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"
    export ROFI_CHOICE='^Тема:'
    record_theme_mode

    run "$SETTINGS"
    [ "$status" -eq 0 ]
    [ "$(cat "$XDG_CONFIG_HOME/hypr/palette-mode")" = dynamic ]
    ! grep -q '^theme-mode ' "$CALLS"
}

# The state rows must not read the marker files directly any more: a stray
# marker page must not steer the displayed mode. (Guards the removed reads.)
@test "the settings center does not read a palette marker file directly" {
    printf 'light\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"
    : >"$XDG_CONFIG_HOME/hypr/dynamic-theme"

    run run_menu
    [[ "$output" == *"Светлая тема: вкл"* ]]
    [[ "$output" == *"Тема: готика (фикс.)"* ]]
}

# The keybind row delegates to keybinds.sh (the tsv cheatsheet) rather than
# grepping binds.conf: there must be one view of the keybinds.
@test "the keybind row routes through keybinds.sh" {
    export ROFI_CHOICE='^Клавиши$'
    record_keybinds

    run "$SETTINGS"
    [ "$status" -eq 0 ]
    grep -qx 'keybinds' "$CALLS"
}
