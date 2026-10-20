#!/usr/bin/env bats
# Tests for config/hypr/scripts/osd.sh — SwayOSD when present, wpctl and
# brightnessctl when it is not. Both paths are stubs, so no audio or backlight
# is touched.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    MODULE="$REPO_ROOT/config/hypr/scripts/osd.sh"

    CALLS="$BATS_TEST_TMPDIR/calls.log"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"
    export CALLS STUB_BIN
    export PATH="$STUB_BIN:$PATH"

    cat >"$STUB_BIN/swayosd-client" <<'EOF'
#!/usr/bin/env bash
printf 'swayosd-client %s\n' "$*" >>"$CALLS"
exit "${SWAYOSD_RC:-0}"
EOF
    cat >"$STUB_BIN/wpctl" <<'EOF'
#!/usr/bin/env bash
printf 'wpctl %s\n' "$*" >>"$CALLS"
EOF
    cat >"$STUB_BIN/brightnessctl" <<'EOF'
#!/usr/bin/env bash
printf 'brightnessctl %s\n' "$*" >>"$CALLS"
EOF
    chmod +x "$STUB_BIN"/*
}

@test "volume up prefers SwayOSD and does not touch wpctl" {
    run "$MODULE" volume up
    [ "$status" -eq 0 ]
    grep -qx 'swayosd-client --output-volume raise' "$CALLS"
    ! grep -q '^wpctl' "$CALLS"
}

@test "volume down falls back to wpctl without SwayOSD" {
    rm -f "$STUB_BIN/swayosd-client"

    run "$MODULE" volume down
    [ "$status" -eq 0 ]
    grep -qx 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-' "$CALLS"
}

@test "mute falls back to wpctl" {
    rm -f "$STUB_BIN/swayosd-client"

    run "$MODULE" volume mute
    [ "$status" -eq 0 ]
    grep -qx 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle' "$CALLS"
}

@test "a failing SwayOSD client falls back instead of losing the key" {
    export SWAYOSD_RC=1

    run "$MODULE" volume up
    [ "$status" -eq 0 ]
    grep -qx 'swayosd-client --output-volume raise' "$CALLS"
    grep -qx 'wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+' "$CALLS"
}

@test "brightness uses SwayOSD when it is alive" {
    run "$MODULE" brightness down
    [ "$status" -eq 0 ]
    grep -qx 'swayosd-client --brightness lower' "$CALLS"
    ! grep -q '^brightnessctl' "$CALLS"
}

@test "brightness falls back to brightnessctl" {
    rm -f "$STUB_BIN/swayosd-client"

    run "$MODULE" brightness up
    [ "$status" -eq 0 ]
    grep -qx 'brightnessctl set 5%+' "$CALLS"
}

@test "status reports whether the OSD is available" {
    run "$MODULE" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"swayosd"* ]]

    rm -f "$STUB_BIN/swayosd-client"
    run "$MODULE" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"выключен"* ]]
}

@test "an unknown action prints usage" {
    run "$MODULE" volume sideways
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
