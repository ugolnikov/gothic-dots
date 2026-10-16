#!/usr/bin/env bats
# Tests for the login entry point (config/hypr/scripts/theme.sh). Run with:
#
#   bats tests/
#
# theme.sh keeps wallpaper selection and the lock-screen copy, but delegates the
# palette to the module (palette.sh). These tests drive it against a throwaway
# config tree with the leaf binaries (wallpaper daemon, generator, reload
# consumers) stubbed on PATH, so no compositor is needed and the real ~/.config
# is never touched.

load helpers

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    THEME="$REPO_ROOT/config/hypr/scripts/theme.sh"
    SCRIPTS="$REPO_ROOT/config/hypr/scripts"

    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
    mkdir -p "$XDG_CONFIG_HOME/hypr/scripts" "$XDG_CACHE_HOME"

    # theme.sh resolves its helpers through $XDG_CONFIG_HOME/hypr/scripts.
    # Link the real wallpaper/palette modules there so the login run exercises
    # the true delegation seam against the throwaway tree.
    ln -s "$SCRIPTS/wallpaper.sh" "$XDG_CONFIG_HOME/hypr/scripts/wallpaper.sh"
    ln -s "$SCRIPTS/palette.sh" "$XDG_CONFIG_HOME/hypr/scripts/palette.sh"

    # Leaf binaries the helpers shell out to are stubbed on PATH; each records
    # the call so the login run can be observed without a session.
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    export CALLS
    export PATH="$STUB_BIN:$PATH"

    for tool in awww awww-daemon mpvpaper pgrep hyprctl pkill swaync-client notify-send; do
        recorder_stub "$tool"
    done
    # pgrep returning 0 pretends the wallpaper daemon is already up, so the
    # static path does not spawn (and sleep for) a real daemon.
    cat >"$STUB_BIN/pgrep" <<EOF
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$STUB_BIN/pgrep"

    stub_wallust
}

# recorder_stub <name> — a fake binary that appends "<name> <args>" to $CALLS.
recorder_stub() {
    local name="$1"
    cat >"$STUB_BIN/$name" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$name \$*" >>"\$CALLS"
EOF
    chmod +x "$STUB_BIN/$name"
}

@test "theme.sh sets the wallpaper and saves the lock-screen copy" {
    img="$BATS_TEST_TMPDIR/wall.png"
    printf 'image-bytes\n' >"$img"

    run "$THEME" "$img"
    [ "$status" -eq 0 ]

    grep -q "awww img $img" "$CALLS"
    [ "$(cat "$XDG_CONFIG_HOME/hypr/wallpaper.png")" = "image-bytes" ]
}

@test "theme.sh falls back to the saved wallpaper with no argument" {
    mkdir -p "$XDG_CONFIG_HOME/hypr"
    printf 'saved\n' >"$XDG_CONFIG_HOME/hypr/wallpaper.png"

    run "$THEME"
    [ "$status" -eq 0 ]

    grep -q "awww img $XDG_CONFIG_HOME/hypr/wallpaper.png" "$CALLS"
}

@test "theme.sh picks a random wallpaper when the marker is set" {
    export HOME="$BATS_TEST_TMPDIR/home"
    # All three search roots exist, as they do on a real machine.
    mkdir -p "$HOME/Wallpapers" "$HOME/Pictures" "$XDG_CONFIG_HOME/hypr/wallpapers" \
        "$XDG_CONFIG_HOME/hypr"
    : >"$XDG_CONFIG_HOME/hypr/random-wallpaper"
    printf 'rand\n' >"$HOME/Wallpapers/only.png"

    run "$THEME"
    [ "$status" -eq 0 ]

    grep -q "awww img $HOME/Wallpapers/only.png" "$CALLS"
    [ "$(cat "$XDG_CONFIG_HOME/hypr/wallpaper.png")" = "rand" ]
}

@test "theme.sh applies the dark mode through the module" {
    img="$BATS_TEST_TMPDIR/wall.png"
    printf 'img\n' >"$img"

    run "$THEME" "$img"
    [ "$status" -eq 0 ]

    # dark == no generated content, but the files stay importable and the
    # consumers were reloaded by the module.
    assert_targets_exist_empty
    grep -qx 'hyprctl reload' "$CALLS"
    grep -qx 'pkill -SIGUSR2 -x waybar' "$CALLS"
    grep -qx 'swaync-client --reload-css' "$CALLS"
}

@test "theme.sh applies the light palette through the module" {
    img="$BATS_TEST_TMPDIR/wall.png"
    printf 'img\n' >"$img"
    mkdir -p "$XDG_CONFIG_HOME/hypr"
    printf 'light\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"

    run "$THEME" "$img"
    [ "$status" -eq 0 ]

    grep -q '#f2efe7' "$XDG_CONFIG_HOME/waybar/colors.dynamic.css"
    grep -q '#f2efe7' "$XDG_CONFIG_HOME/rofi/colors.dynamic.rasi"
}

@test "theme.sh applies the wallpaper-derived palette through the module" {
    img="$BATS_TEST_TMPDIR/wall.png"
    printf 'img\n' >"$img"
    mkdir -p "$XDG_CONFIG_HOME/hypr"
    printf 'dynamic\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"

    run "$THEME" "$img"
    [ "$status" -eq 0 ]

    grep -q "generated from run $img" "$XDG_CONFIG_HOME/waybar/colors.dynamic.css"
    grep -qx "wallust run $img" "$CALLS"
}

# The login command must not keep its own copy of the palette work: it hands
# the chosen wallpaper to the module and does nothing else with colour.
@test "theme.sh delegates the palette and does not reload or pre-create targets itself" {
    rm -f "$XDG_CONFIG_HOME/hypr/scripts/palette.sh"
    cat >"$XDG_CONFIG_HOME/hypr/scripts/palette.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "palette $*" >>"$CALLS"
EOF
    chmod +x "$XDG_CONFIG_HOME/hypr/scripts/palette.sh"

    img="$BATS_TEST_TMPDIR/wall.png"
    printf 'img\n' >"$img"

    run "$THEME" "$img"
    [ "$status" -eq 0 ]

    grep -qx "palette apply $img" "$CALLS"
    ! grep -q 'hyprctl reload' "$CALLS"
    ! grep -q 'swaync-client' "$CALLS"
    ! grep -q 'wallust' "$CALLS"
    [ ! -e "$XDG_CONFIG_HOME/waybar/colors.dynamic.css" ]
}
