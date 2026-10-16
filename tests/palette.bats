#!/usr/bin/env bats
# Tests for the palette module (config/hypr/scripts/palette.sh). Run with:
#
#   bats tests/
#
# The module owns the generated colour files, so the module is driven against a
# throwaway config tree (XDG_CONFIG_HOME/XDG_CACHE_HOME redirected) with the
# reload consumers stubbed on PATH. No compositor is needed, and the real
# ~/.config is never touched.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    PALETTE="$REPO_ROOT/config/hypr/scripts/palette.sh"

    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
    mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"

    # Stub the reload consumers; each records the call so we can assert the
    # reload happened without a running bar or window manager.
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"
    RELOAD_LOG="$BATS_TEST_TMPDIR/reload.log"
    export RELOAD_LOG
    for tool in hyprctl pkill swaync-client; do
        cat >"$STUB_BIN/$tool" <<EOF
#!/usr/bin/env bash
echo "$tool \$*" >>"\$RELOAD_LOG"
EOF
        chmod +x "$STUB_BIN/$tool"
    done
    export PATH="$STUB_BIN:$PATH"
}

# targets — the five generated files, one per colour consumer.
targets() {
    printf '%s\n' \
        "$XDG_CONFIG_HOME/hypr/conf.d/colors.dynamic.conf" \
        "$XDG_CONFIG_HOME/waybar/colors.dynamic.css" \
        "$XDG_CONFIG_HOME/rofi/colors.dynamic.rasi" \
        "$XDG_CONFIG_HOME/kitty/colors.dynamic.conf" \
        "$XDG_CONFIG_HOME/swaync/colors.dynamic.css"
}

assert_targets_exist_empty() {
    local f
    while IFS= read -r f; do
        if [ ! -f "$f" ]; then
            echo "missing target: $f" >&2
            return 1
        fi
        if [ -s "$f" ]; then
            echo "target is not empty: $f" >&2
            return 1
        fi
    done < <(targets)
}

# expect_line <pattern> <file> — assert the file carries a consumer-visible
# definition. Explicit failure so an early miss does not pass silently.
expect_line() {
    if ! grep -q -- "$1" "$2"; then
        echo "expected '$1' in $2" >&2
        return 1
    fi
}

# assert_light_palette — каждый target несёт светлую «ivory» палитру в своём
# формате. Проверяем те определения, за которые цепляются потребители, а не
# весь файл целиком.
assert_light_palette() {
    local hypr="$XDG_CONFIG_HOME/hypr/conf.d/colors.dynamic.conf"
    local waybar="$XDG_CONFIG_HOME/waybar/colors.dynamic.css"
    local rofi="$XDG_CONFIG_HOME/rofi/colors.dynamic.rasi"
    local kitty="$XDG_CONFIG_HOME/kitty/colors.dynamic.conf"
    local swaync="$XDG_CONFIG_HOME/swaync/colors.dynamic.css"

    expect_line 'col.active_border = rgba(8c1220ff)' "$hypr" || return 1
    expect_line 'background_color = rgba(f2efe7ff)' "$hypr" || return 1
    expect_line '@define-color base     #f2efe7;' "$waybar" || return 1
    expect_line '@define-color text     #2a2723;' "$waybar" || return 1
    expect_line 'base:      #f2efe7;' "$rofi" || return 1
    expect_line 'text:      #2a2723;' "$rofi" || return 1
    expect_line 'background              #f2efe7' "$kitty" || return 1
    expect_line 'foreground              #2a2723' "$kitty" || return 1
    expect_line '@define-color base     #f2efe7;' "$swaync" || return 1
    expect_line '@define-color text     #2a2723;' "$swaync" || return 1
}

@test "palette.sh set light writes the ivory palette and reports light" {
    run "$PALETTE" set light
    [ "$status" -eq 0 ]
    assert_light_palette

    run "$PALETTE" status
    [ "$output" = "light" ]
}

assert_targets_exist_nonempty() {
    local f
    while IFS= read -r f; do
        if [ ! -s "$f" ]; then
            echo "target missing or empty: $f" >&2
            return 1
        fi
    done < <(targets)
}

# stub_wallust — substitute the external palette generator with a fake that
# writes every target, so the dynamic path is testable without image
# processing. It records the arguments it was handed. Set WALLUST_FAIL=1 to
# make it fail without writing anything.
stub_wallust() {
    cat >"$STUB_BIN/wallust" <<'EOF'
#!/usr/bin/env bash
echo "wallust $*" >>"$RELOAD_LOG"
[ "${WALLUST_FAIL:-}" = 1 ] && exit 1
for f in \
    "$XDG_CONFIG_HOME/hypr/conf.d/colors.dynamic.conf" \
    "$XDG_CONFIG_HOME/waybar/colors.dynamic.css" \
    "$XDG_CONFIG_HOME/rofi/colors.dynamic.rasi" \
    "$XDG_CONFIG_HOME/kitty/colors.dynamic.conf" \
    "$XDG_CONFIG_HOME/swaync/colors.dynamic.css"; do
    mkdir -p "$(dirname "$f")"
    printf 'generated from %s\n' "$*" >"$f"
done
EOF
    chmod +x "$STUB_BIN/wallust"
}

@test "palette.sh status reports dark before any mode is chosen" {
    run "$PALETTE" status
    [ "$status" -eq 0 ]
    [ "$output" = "dark" ]
}

@test "palette.sh apply pre-creates every target file, empty" {
    run "$PALETTE" apply
    [ "$status" -eq 0 ]
    assert_targets_exist_empty
}

@test "palette.sh set dark empties every target and reports dark" {
    mkdir -p "$XDG_CONFIG_HOME/hypr/conf.d"
    printf 'stale palette\n' >"$XDG_CONFIG_HOME/hypr/conf.d/colors.dynamic.conf"

    run "$PALETTE" set dark
    [ "$status" -eq 0 ]
    assert_targets_exist_empty

    run "$PALETTE" status
    [ "$output" = "dark" ]
}

@test "palette.sh clear empties every target and returns to dark" {
    run "$PALETTE" clear
    [ "$status" -eq 0 ]
    assert_targets_exist_empty

    run "$PALETTE" status
    [ "$output" = "dark" ]
}

@test "palette.sh reloads the colour consumers after a mode change" {
    run "$PALETTE" set dark
    [ "$status" -eq 0 ]

    [ -f "$RELOAD_LOG" ]
    grep -qx 'hyprctl reload' "$RELOAD_LOG"
    grep -qx 'pkill -SIGUSR2 -x waybar' "$RELOAD_LOG"
    grep -qx 'swaync-client --reload-css' "$RELOAD_LOG"
}

@test "palette.sh toggle from dark reaches light" {
    run "$PALETTE" toggle
    [ "$status" -eq 0 ]
    assert_light_palette

    run "$PALETTE" status
    [ "$output" = "light" ]
}

@test "palette.sh toggle from light returns to dark" {
    "$PALETTE" set light

    run "$PALETTE" toggle
    [ "$status" -eq 0 ]
    assert_targets_exist_empty

    run "$PALETTE" status
    [ "$output" = "dark" ]
}

@test "palette.sh apply refills the ivory palette while in light mode" {
    "$PALETTE" set light
    : >"$XDG_CONFIG_HOME/rofi/colors.dynamic.rasi"

    run "$PALETTE" apply
    [ "$status" -eq 0 ]
    assert_light_palette

    run "$PALETTE" status
    [ "$output" = "light" ]
}

@test "palette.sh reloads the colour consumers after applying light" {
    run "$PALETTE" set light
    [ "$status" -eq 0 ]

    grep -qx 'hyprctl reload' "$RELOAD_LOG"
    grep -qx 'pkill -SIGUSR2 -x waybar' "$RELOAD_LOG"
    grep -qx 'swaync-client --reload-css' "$RELOAD_LOG"
}

@test "palette.sh clear after light empties every target and returns to dark" {
    "$PALETTE" set light

    run "$PALETTE" clear
    [ "$status" -eq 0 ]
    assert_targets_exist_empty

    run "$PALETTE" status
    [ "$output" = "dark" ]
}

@test "palette.sh ignores a missing consumer without error" {
    minbin="$BATS_TEST_TMPDIR/minbin"
    mkdir -p "$minbin"
    for c in bash cat dirname mkdir rm touch; do
        p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$minbin/$c"
    done

    run env PATH="$minbin" "$PALETTE" set dark
    [ "$status" -eq 0 ]
}

@test "palette.sh rejects an unknown mode with usage and exit 2" {
    run "$PALETTE" set chartreuse
    [ "$status" -eq 2 ]
    [[ "$output" == *usage* ]]
}

@test "palette.sh reports the legacy light marker while no mode is chosen" {
    mkdir -p "$XDG_CONFIG_HOME/hypr"
    : >"$XDG_CONFIG_HOME/hypr/light-theme"

    run "$PALETTE" status
    [ "$status" -eq 0 ]
    [ "$output" = "light" ]
}

@test "palette.sh status prefers the persisted mode over a legacy marker" {
    mkdir -p "$XDG_CONFIG_HOME/hypr"
    : >"$XDG_CONFIG_HOME/hypr/light-theme"
    printf 'dynamic\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"

    run "$PALETTE" status
    [ "$status" -eq 0 ]
    [ "$output" = "dynamic" ]
}

@test "palette.sh migrates both legacy markers to one mode on first read" {
    mkdir -p "$XDG_CONFIG_HOME/hypr"
    : >"$XDG_CONFIG_HOME/hypr/light-theme"
    : >"$XDG_CONFIG_HOME/hypr/dynamic-theme"

    run "$PALETTE" status
    [ "$status" -eq 0 ]
    [ "$output" = "light" ]

    # Единственное значение записано, оба старых маркера убраны.
    [ "$(cat "$XDG_CONFIG_HOME/hypr/palette-mode")" = light ]
    [ ! -e "$XDG_CONFIG_HOME/hypr/light-theme" ]
    [ ! -e "$XDG_CONFIG_HOME/hypr/dynamic-theme" ]
}

@test "palette.sh migrates a legacy dynamic marker to the single mode" {
    mkdir -p "$XDG_CONFIG_HOME/hypr"
    : >"$XDG_CONFIG_HOME/hypr/dynamic-theme"

    run "$PALETTE" status
    [ "$status" -eq 0 ]
    [ "$output" = "dynamic" ]

    [ "$(cat "$XDG_CONFIG_HOME/hypr/palette-mode")" = dynamic ]
    [ ! -e "$XDG_CONFIG_HOME/hypr/dynamic-theme" ]
}

@test "palette.sh setting a mode leaves no trace of the legacy markers" {
    mkdir -p "$XDG_CONFIG_HOME/hypr"
    : >"$XDG_CONFIG_HOME/hypr/light-theme"
    : >"$XDG_CONFIG_HOME/hypr/dynamic-theme"

    run "$PALETTE" set dynamic
    [ "$status" -eq 0 ]

    [ "$(cat "$XDG_CONFIG_HOME/hypr/palette-mode")" = dynamic ]
    [ ! -e "$XDG_CONFIG_HOME/hypr/light-theme" ]
    [ ! -e "$XDG_CONFIG_HOME/hypr/dynamic-theme" ]
}

@test "palette.sh set dynamic generates the targets through the generator" {
    stub_wallust
    image="$BATS_TEST_TMPDIR/wall.png"

    run "$PALETTE" set dynamic "$image"
    [ "$status" -eq 0 ]
    assert_targets_exist_nonempty
    grep -qx "wallust run $image" "$RELOAD_LOG"

    run "$PALETTE" status
    [ "$status" -eq 0 ]
    [ "$output" = "dynamic" ]
}

@test "palette.sh apply in dynamic mode uses the saved wallpaper" {
    stub_wallust
    mkdir -p "$XDG_CONFIG_HOME/hypr"
    printf 'wallpaper\n' >"$XDG_CONFIG_HOME/hypr/wallpaper.png"
    printf 'dynamic\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"

    run "$PALETTE" apply
    [ "$status" -eq 0 ]
    assert_targets_exist_nonempty
    grep -qx "wallust run $XDG_CONFIG_HOME/hypr/wallpaper.png" "$RELOAD_LOG"
}

@test "palette.sh keeps targets importable when generation fails" {
    stub_wallust
    export WALLUST_FAIL=1

    run "$PALETTE" set dynamic "$BATS_TEST_TMPDIR/missing.png"
    [ "$status" -eq 0 ]
    assert_targets_exist_empty

    run "$PALETTE" status
    [ "$status" -eq 0 ]
    [ "$output" = "dynamic" ]
}
