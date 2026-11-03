#!/usr/bin/env bats
# Tests for config/hypr/scripts/dismiss.sh — the dismiss keybind clears the
# notifications of whichever daemon the `notifications` marker names, and falls
# back to the other one when the first client is missing. Both clients are
# stubs on PATH, so no real notification daemon is ever called.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    MODULE="$REPO_ROOT/config/hypr/scripts/dismiss.sh"

    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    mkdir -p "$XDG_CONFIG_HOME/hypr"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUB_BIN"
    export STUB_BIN CALLS
    export PATH="$STUB_BIN:$PATH"

    cat >"$STUB_BIN/makoctl" <<'EOF'
#!/usr/bin/env bash
printf 'makoctl %s\n' "$*" >>"$CALLS"
EOF
    cat >"$STUB_BIN/swaync-client" <<'EOF'
#!/usr/bin/env bash
printf 'swaync-client %s\n' "$*" >>"$CALLS"
EOF
    chmod +x "$STUB_BIN"/*
}

@test "the swaync marker dismisses through swaync-client" {
    printf 'swaync\n' >"$XDG_CONFIG_HOME/hypr/notifications"

    run "$MODULE"
    [ "$status" -eq 0 ]
    grep -qx 'swaync-client --close-all' "$CALLS"
    ! grep -q '^makoctl' "$CALLS"
}

@test "the mako marker dismisses through makoctl" {
    printf 'mako\n' >"$XDG_CONFIG_HOME/hypr/notifications"

    run "$MODULE"
    [ "$status" -eq 0 ]
    grep -qx 'makoctl dismiss -a' "$CALLS"
    ! grep -q '^swaync-client' "$CALLS"
}

@test "a missing marker falls back to mako" {
    run "$MODULE"
    [ "$status" -eq 0 ]
    grep -qx 'makoctl dismiss -a' "$CALLS"
}

# The marker can outlive the client: switching back to mako must not leave the
# keybind doing nothing just because swaync-client was uninstalled.
@test "a swaync marker without swaync-client falls back to mako" {
    printf 'swaync\n' >"$XDG_CONFIG_HOME/hypr/notifications"
    rm -f "$STUB_BIN/swaync-client"

    run "$MODULE"
    [ "$status" -eq 0 ]
    grep -qx 'makoctl dismiss -a' "$CALLS"
}

@test "no notification client installed is not an error" {
    rm -f "$STUB_BIN/makoctl" "$STUB_BIN/swaync-client"

    run "$MODULE"
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}
