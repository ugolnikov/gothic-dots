#!/usr/bin/env bats
# Tests for config/hypr/scripts/notifications.sh. Run with:
#
#   bats tests/
#
# The wrapper reads the `notifications` marker, stops both daemons and execs the
# chosen one. Because it execs, it is run as a subprocess and each stub records
# itself in a call log. A throwaway HOME holds the marker and mako/swaync/pkill
# are stubbed on PATH, so no real process is ever signalled.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    NOTIFICATIONS="$REPO_ROOT/config/hypr/scripts/notifications.sh"

    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_CACHE_HOME="$HOME/.cache"
    mkdir -p "$XDG_CONFIG_HOME/hypr" "$XDG_CACHE_HOME"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUB_BIN"
    export STUB_BIN CALLS
    export PATH="$STUB_BIN:$PATH"

    for tool in pkill mako swaync; do
        cat >"$STUB_BIN/$tool" <<EOF
#!/usr/bin/env bash
printf '%s' "$tool" >>"\$CALLS"
for a in "\$@"; do printf ' %s' "\$a" >>"\$CALLS"; done
printf '\n' >>"\$CALLS"
EOF
        chmod +x "$STUB_BIN/$tool"
    done
}

@test "the swaync marker runs swaync and not mako" {
    printf 'swaync\n' >"$XDG_CONFIG_HOME/hypr/notifications"

    run "$NOTIFICATIONS"
    [ "$status" -eq 0 ]
    grep -qx 'swaync' "$CALLS"
    ! grep -q '^mako' "$CALLS"
}

@test "the mako marker runs mako and not swaync" {
    printf 'mako\n' >"$XDG_CONFIG_HOME/hypr/notifications"

    run "$NOTIFICATIONS"
    [ "$status" -eq 0 ]
    grep -qx 'mako' "$CALLS"
    ! grep -q '^swaync' "$CALLS"
}

@test "a missing marker falls back to mako" {
    run "$NOTIFICATIONS"
    [ "$status" -eq 0 ]
    grep -qx 'mako' "$CALLS"
}

# Both daemons must be stopped first: otherwise the old one keeps its socket and
# the newly started one fails to claim it.
@test "both daemons are stopped before one is started" {
    printf 'swaync\n' >"$XDG_CONFIG_HOME/hypr/notifications"

    run "$NOTIFICATIONS"
    [ "$status" -eq 0 ]
    grep -qx 'pkill -x swaync' "$CALLS"
    grep -qx 'pkill -x mako' "$CALLS"
}

# The wallust-generated mako config is passed with -c when it exists.
@test "mako picks up the wallust config when present" {
    printf 'mako\n' >"$XDG_CONFIG_HOME/hypr/notifications"
    mkdir -p "$HOME/.cache/wallust"
    : >"$HOME/.cache/wallust/mako"

    run "$NOTIFICATIONS"
    [ "$status" -eq 0 ]
    grep -qx "mako -c $HOME/.cache/wallust/mako" "$CALLS"
}

@test "mako starts without -c when the wallust config is absent" {
    printf 'mako\n' >"$XDG_CONFIG_HOME/hypr/notifications"

    run "$NOTIFICATIONS"
    [ "$status" -eq 0 ]
    grep -qx 'mako' "$CALLS"
}
