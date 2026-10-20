#!/usr/bin/env bats
# Tests for config/hypr/scripts/preset.sh — named settings bundles with
# rollback. Run with:
#
#   bats tests/
#
# Every module the preset drives is a stateful stub: palette/effects/controls
# keep their value in a file, pgrep/waybar/pkill model the bar, and
# powerprofilesctl keeps a profile. So apply/off can be asserted by reading the
# same state the modules would have written, without a session.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    PRESET="$REPO_ROOT/config/hypr/scripts/preset.sh"
    STATE_DIR="$BATS_TEST_TMPDIR/config/hypr"
    MODS="$BATS_TEST_TMPDIR/mods"

    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    export PRESET_SCRIPTS="$MODS"
    mkdir -p "$HOME" "$STATE_DIR/presets" "$STATE_DIR/presets.local" "$MODS"

    CALLS="$BATS_TEST_TMPDIR/calls.log"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"
    export CALLS STATE_DIR
    export PATH="$STUB_BIN:$PATH"

    # State the stubs start from: dynamic palette, animations on, night light on,
    # bar running, balanced power.
    printf 'dynamic\n' >"$STATE_DIR/palette"
    printf 'on\n' >"$STATE_DIR/animations"
    printf 'on\n' >"$STATE_DIR/night"
    printf 'off\n' >"$STATE_DIR/dnd"
    printf 'off\n' >"$STATE_DIR/caffeine"
    printf 'on\n' >"$STATE_DIR/bar"
    printf 'balanced\n' >"$STATE_DIR/power"

    cat >"$MODS/palette.sh" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    status) cat "$STATE_DIR/palette" ;;
    set) printf '%s\n' "$2" >"$STATE_DIR/palette" ;;
esac
exit 0
EOF
    cat >"$MODS/effects.sh" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    status) cat "$STATE_DIR/animations" ;;
    animations) printf '%s\n' "$2" >"$STATE_DIR/animations" ;;
esac
exit 0
EOF
    cat >"$MODS/controls.sh" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    get) cat "$STATE_DIR/$2" 2>/dev/null || echo off ;;
    night | dnd | caffeine) printf '%s\n' "$2" >"$STATE_DIR/$1" ;;
esac
exit 0
EOF
    cat >"$STUB_BIN/powerprofilesctl" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    get) cat "$STATE_DIR/power" ;;
    set) printf '%s\n' "$2" >"$STATE_DIR/power" ;;
esac
EOF
    cat >"$STUB_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
[ "$(cat "$STATE_DIR/bar" 2>/dev/null || echo on)" = on ]
EOF
    cat >"$STUB_BIN/pkill" <<'EOF'
#!/usr/bin/env bash
printf 'off\n' >"$STATE_DIR/bar"
printf '%s\n' "pkill $*" >>"$CALLS"
EOF
    cat >"$STUB_BIN/waybar" <<'EOF'
#!/usr/bin/env bash
printf 'on\n' >"$STATE_DIR/bar"
printf '%s\n' "waybar $*" >>"$CALLS"
EOF
    cat >"$STUB_BIN/notify-send" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    cat >"$STUB_BIN/rofi" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
[ -n "${ROFI_CHOICE:-}" ] && printf '%s\n' "$ROFI_CHOICE"
exit 0
EOF
    chmod +x "$MODS"/* "$STUB_BIN"/*

    cat >"$STATE_DIR/presets/gaming.conf" <<'EOF'
# gaming
animations=off
dnd=on
caffeine=on
night=off
bar=off
power=performance
EOF
    cat >"$STATE_DIR/presets/work.conf" <<'EOF'
# work
animations=off
dnd=off
caffeine=on
bar=on
power=balanced
EOF
    cat >"$STATE_DIR/presets.local/custom.conf" <<'EOF'
# only DND
dnd=on
EOF
}

@test "list merges built-in and user presets" {
    run "$PRESET" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"gaming"* ]]
    [[ "$output" == *"work"* ]]
    [[ "$output" == *"custom"* ]]
}

@test "show prints the preset contents" {
    run "$PRESET" show gaming
    [ "$status" -eq 0 ]
    [[ "$output" == *"dnd=on"* ]]
    [[ "$output" == *"power=performance"* ]]
}

@test "apply changes every key and snapshots the previous state" {
    run "$PRESET" apply gaming
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE_DIR/animations")" = off ]
    [ "$(cat "$STATE_DIR/dnd")" = on ]
    [ "$(cat "$STATE_DIR/caffeine")" = on ]
    [ "$(cat "$STATE_DIR/night")" = off ]
    [ "$(cat "$STATE_DIR/bar")" = off ]
    [ "$(cat "$STATE_DIR/power")" = performance ]
    [ "$(cat "$STATE_DIR/palette")" = dynamic ]
    [ "$(cat "$STATE_DIR/preset-active")" = gaming ]

    grep -qx 'animations=on' "$STATE_DIR/preset-previous"
    grep -qx 'dnd=off' "$STATE_DIR/preset-previous"
    grep -qx 'caffeine=off' "$STATE_DIR/preset-previous"
    grep -qx 'night=on' "$STATE_DIR/preset-previous"
    grep -qx 'bar=on' "$STATE_DIR/preset-previous"
    grep -qx 'power=balanced' "$STATE_DIR/preset-previous"
}

@test "off restores the snapshot and clears the markers" {
    "$PRESET" apply gaming

    run "$PRESET" off
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE_DIR/animations")" = on ]
    [ "$(cat "$STATE_DIR/dnd")" = off ]
    [ "$(cat "$STATE_DIR/caffeine")" = off ]
    [ "$(cat "$STATE_DIR/night")" = on ]
    [ "$(cat "$STATE_DIR/bar")" = on ]
    [ "$(cat "$STATE_DIR/power")" = balanced ]
    [ ! -e "$STATE_DIR/preset-active" ]
    [ ! -e "$STATE_DIR/preset-previous" ]
}

@test "a second preset rolls the first back before snapshotting" {
    "$PRESET" apply gaming
    run "$PRESET" apply work
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE_DIR/preset-active")" = work ]
    # work touches neither night nor the palette: night is back on, as it was
    # before gaming, and the palette was never in a preset.
    [ "$(cat "$STATE_DIR/night")" = on ]
    [ "$(cat "$STATE_DIR/palette")" = dynamic ]
    # work does not touch night, so the new snapshot has no night row; the
    # state itself is back to on because gaming was rolled back first.
    ! grep -q '^night=' "$STATE_DIR/preset-previous"
    grep -qx 'animations=on' "$STATE_DIR/preset-previous"

    "$PRESET" off
    [ "$(cat "$STATE_DIR/animations")" = on ]
    [ "$(cat "$STATE_DIR/night")" = on ]
    [ "$(cat "$STATE_DIR/power")" = balanced ]
}

@test "a subset preset snapshots only the keys it changes" {
    run "$PRESET" apply custom
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE_DIR/dnd")" = on ]
    [ "$(cat "$STATE_DIR/animations")" = on ]
    [ "$(cat "$STATE_DIR/preset-previous")" = "dnd=off" ]
}

@test "an unknown key is rejected before anything changes" {
    cat >"$STATE_DIR/presets.local/broken.conf" <<'EOF'
dnd=on
sparkles=on
EOF

    run "$PRESET" apply broken
    [ "$status" -eq 2 ]
    [[ "$output" == *"неизвестный ключ"* ]]
    [ "$(cat "$STATE_DIR/dnd")" = off ]
    [ ! -e "$STATE_DIR/preset-active" ]
}

@test "off with no active preset is a no-op" {
    run "$PRESET" off
    [ "$status" -eq 0 ]
    [[ "$output" == *"активного пресета нет"* ]]
}

@test "a missing preset names the list command" {
    run "$PRESET" apply ghost
    [ "$status" -eq 2 ]
    [[ "$output" == *"preset.sh list"* ]]
}

@test "the menu applies the picked preset" {
    export ROFI_CHOICE="Применить: gaming"

    run "$PRESET" menu
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE_DIR/preset-active")" = gaming ]
}
