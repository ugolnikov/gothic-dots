#!/usr/bin/env bats
# Tests for config/hypr/scripts/effects.sh — the animations toggle. Run with:
#
#   bats tests/
#
# The module owns animations.dynamic.conf and applies it through hyprctl; the
# compositor is stubbed and the config tree is a throwaway.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    EFFECTS="$REPO_ROOT/config/hypr/scripts/effects.sh"

    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME/hypr/conf.d"

    CALLS="$BATS_TEST_TMPDIR/calls.log"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"
    export CALLS
    export PATH="$STUB_BIN:$PATH"

    cat >"$STUB_BIN/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "hyprctl $*" >>"$CALLS"
EOF
    chmod +x "$STUB_BIN/hyprctl"
}

@test "animations are off when no generated file exists" {
    run "$EFFECTS" status
    [ "$status" -eq 0 ]
    [ "$output" = off ]
}

@test "animations on writes the file and applies the keyword" {
    run "$EFFECTS" animations on
    [ "$status" -eq 0 ]
    grep -qx 'animations { enabled = true }' \
        "$XDG_CONFIG_HOME/hypr/conf.d/animations.dynamic.conf"
    grep -qx 'hyprctl keyword animations:enabled true' "$CALLS"

    run "$EFFECTS" status
    [ "$output" = on ]
}

@test "animations off writes false" {
    "$EFFECTS" animations on
    run "$EFFECTS" animations off
    [ "$status" -eq 0 ]
    grep -qx 'animations { enabled = false }' \
        "$XDG_CONFIG_HOME/hypr/conf.d/animations.dynamic.conf"
    [ "$("$EFFECTS" status)" = off ]
}

@test "toggle flips the current state" {
    run "$EFFECTS" animations toggle
    [ "$output" = "" ]
    [ "$("$EFFECTS" status)" = on ]

    "$EFFECTS" animations toggle
    [ "$("$EFFECTS" status)" = off ]
}

@test "an unknown action prints usage" {
    run "$EFFECTS" bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
