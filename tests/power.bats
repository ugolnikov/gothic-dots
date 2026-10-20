#!/usr/bin/env bats
# Tests for config/hypr/scripts/power.sh — power-profiles-daemon only.
# powerprofilesctl and rofi are stubs; the chosen profile lives in a temp file.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    MODULE="$REPO_ROOT/config/hypr/scripts/power.sh"
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME"

    CALLS="$BATS_TEST_TMPDIR/calls.log"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    PROFILE_FILE="$BATS_TEST_TMPDIR/profile"
    printf 'balanced\n' >"$PROFILE_FILE"
    mkdir -p "$STUB_BIN"
    export CALLS STUB_BIN PROFILE_FILE
    export PATH="$STUB_BIN:$PATH"

    cat >"$STUB_BIN/powerprofilesctl" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    get) cat "$PROFILE_FILE" ;;
    set)
        printf '%s\n' "$2" >"$PROFILE_FILE"
        printf 'powerprofilesctl %s\n' "$*" >>"$CALLS"
        ;;
esac
EOF
    cat >"$STUB_BIN/rofi" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' "${ROFI_CHOICE:-}"
EOF
    cat >"$STUB_BIN/notify-send" <<'EOF'
#!/usr/bin/env bash
printf 'notify-send %s\n' "$*" >>"$CALLS"
EOF
    chmod +x "$STUB_BIN"/*
}

@test "status prints the current profile" {
    run "$MODULE" status
    [ "$status" -eq 0 ]
    [ "$output" = "питание: balanced" ]
}

@test "a named profile is passed to powerprofilesctl" {
    run "$MODULE" performance
    [ "$status" -eq 0 ]
    [ "$(cat "$PROFILE_FILE")" = performance ]
    grep -qx 'powerprofilesctl set performance' "$CALLS"
}

@test "cycle moves balanced to performance" {
    run "$MODULE" cycle
    [ "$status" -eq 0 ]
    [ "$(cat "$PROFILE_FILE")" = performance ]
}

@test "cycle wraps performance back to saver" {
    printf 'performance\n' >"$PROFILE_FILE"

    run "$MODULE" cycle
    [ "$status" -eq 0 ]
    [ "$(cat "$PROFILE_FILE")" = saver ]
}

@test "cycle moves saver to balanced" {
    printf 'saver\n' >"$PROFILE_FILE"

    run "$MODULE" cycle
    [ "$status" -eq 0 ]
    [ "$(cat "$PROFILE_FILE")" = balanced ]
}

@test "the menu applies the chosen profile" {
    export ROFI_CHOICE=saver

    run "$MODULE" menu
    [ "$status" -eq 0 ]
    [ "$(cat "$PROFILE_FILE")" = saver ]
}

@test "a missing powerprofilesctl is reported, not faked" {
    rm -f "$STUB_BIN/powerprofilesctl"

    run "$MODULE" balanced
    [ "$status" -eq 1 ]
    [[ "$output" == *"power-profiles-daemon"* ]]
    grep -q 'notify-send' "$CALLS"
}

@test "status without the daemon says so" {
    rm -f "$STUB_BIN/powerprofilesctl"

    run "$MODULE" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"недоступен"* ]]
}

@test "an unknown profile is rejected" {
    run "$MODULE" turbo
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
