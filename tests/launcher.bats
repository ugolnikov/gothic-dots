#!/usr/bin/env bats
# Tests for config/hypr/scripts/launcher.sh (SUPER + D, SUPER + Space). Run with:
#
#   bats tests/
#
# The wrapper prefers tofi-drun and falls back to rofi. It passes the
# wallust-generated tofi config with -c when that file exists. It execs, so it
# is run as a subprocess and the stubs record themselves; the config lives under
# a throwaway HOME, so nothing real is launched.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    LAUNCHER="$REPO_ROOT/config/hypr/scripts/launcher.sh"

    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_CACHE_HOME="$HOME/.cache"
    mkdir -p "$XDG_CACHE_HOME"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUB_BIN"
    export STUB_BIN CALLS
    export PATH="$STUB_BIN:$PATH"

    for tool in tofi-drun rofi; do
        cat >"$STUB_BIN/$tool" <<EOF
#!/usr/bin/env bash
printf '%s' "$tool" >>"\$CALLS"
for a in "\$@"; do printf ' %s' "\$a" >>"\$CALLS"; done
printf '\n' >>"\$CALLS"
EOF
        chmod +x "$STUB_BIN/$tool"
    done
}

@test "tofi-drun is used when available" {
    run "$LAUNCHER"
    [ "$status" -eq 0 ]
    grep -qx 'tofi-drun' "$CALLS"
    ! grep -q '^rofi' "$CALLS"
}

@test "tofi-drun gets the wallust config with -c when it exists" {
    mkdir -p "$XDG_CACHE_HOME/wallust"
    : >"$XDG_CACHE_HOME/wallust/tofi"

    run "$LAUNCHER"
    [ "$status" -eq 0 ]
    grep -qx "tofi-drun -c $XDG_CACHE_HOME/wallust/tofi" "$CALLS"
}

@test "tofi-drun starts without -c when the wallust config is absent" {
    run "$LAUNCHER"
    [ "$status" -eq 0 ]
    grep -qx 'tofi-drun' "$CALLS"
}

@test "rofi is the fallback when tofi-drun is absent" {
    rm -f "$STUB_BIN/tofi-drun"

    run "$LAUNCHER"
    [ "$status" -eq 0 ]
    grep -qx 'rofi -show drun' "$CALLS"
}

# The fallback must not read the tofi config: rofi has its own theme.
@test "rofi is used even when the tofi config exists" {
    rm -f "$STUB_BIN/tofi-drun"
    mkdir -p "$XDG_CACHE_HOME/wallust"
    : >"$XDG_CACHE_HOME/wallust/tofi"

    run "$LAUNCHER"
    [ "$status" -eq 0 ]
    grep -qx 'rofi -show drun' "$CALLS"
}
