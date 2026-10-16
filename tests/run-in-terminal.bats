#!/usr/bin/env bats
# Tests for config/hypr/scripts/run-in-terminal.sh. Run with:
#
#   bats tests/
#
# The wrapper reads the `terminal` marker and execs that terminal, applying the
# per-terminal argument convention. It execs, so it is run as a subprocess and
# each stub records the arguments it was handed. The terminal stubs live on PATH
# and the marker in a throwaway HOME, so nothing real is launched.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    RUN_IN_TERMINAL="$REPO_ROOT/config/hypr/scripts/run-in-terminal.sh"

    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    mkdir -p "$XDG_CONFIG_HOME/hypr"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUB_BIN"
    export STUB_BIN CALLS
    export PATH="$STUB_BIN:$PATH"

    for tool in foot footclient kitty alacritty wezterm; do
        cat >"$STUB_BIN/$tool" <<EOF
#!/usr/bin/env bash
printf '%s' "$tool" >>"\$CALLS"
for a in "\$@"; do printf ' %s' "\$a" >>"\$CALLS"; done
printf '\n' >>"\$CALLS"
EOF
        chmod +x "$STUB_BIN/$tool"
    done
}

@test "foot runs footclient with no command" {
    printf 'foot\n' >"$XDG_CONFIG_HOME/hypr/terminal"

    run "$RUN_IN_TERMINAL"
    [ "$status" -eq 0 ]
    grep -qx 'footclient' "$CALLS"
}

@test "foot passes the command to footclient" {
    printf 'foot\n' >"$XDG_CONFIG_HOME/hypr/terminal"

    run "$RUN_IN_TERMINAL" htop
    [ "$status" -eq 0 ]
    grep -qx 'footclient htop' "$CALLS"
}

@test "a missing marker falls back to footclient" {
    run "$RUN_IN_TERMINAL"
    [ "$status" -eq 0 ]
    grep -qx 'footclient' "$CALLS"
}

@test "foot-raw runs foot without the client shim" {
    printf 'foot-raw\n' >"$XDG_CONFIG_HOME/hypr/terminal"

    run "$RUN_IN_TERMINAL" htop
    [ "$status" -eq 0 ]
    grep -qx 'foot htop' "$CALLS"
}

@test "alacritty uses -e for its command" {
    printf 'alacritty\n' >"$XDG_CONFIG_HOME/hypr/terminal"

    run "$RUN_IN_TERMINAL" htop
    [ "$status" -eq 0 ]
    grep -qx 'alacritty -e htop' "$CALLS"
}

@test "wezterm uses start -- for its command" {
    printf 'wezterm\n' >"$XDG_CONFIG_HOME/hypr/terminal"

    run "$RUN_IN_TERMINAL" htop
    [ "$status" -eq 0 ]
    grep -qx 'wezterm start -- htop' "$CALLS"
}

@test "kitty passes the command straight through" {
    printf 'kitty\n' >"$XDG_CONFIG_HOME/hypr/terminal"

    run "$RUN_IN_TERMINAL" htop
    [ "$status" -eq 0 ]
    grep -qx 'kitty htop' "$CALLS"
}

# rofi/.desktop entries call the wrapper as `-e <cmd>`; the flag is consumed and
# never forwarded to the terminal.
@test "the -e compatibility flag is consumed, not forwarded" {
    printf 'alacritty\n' >"$XDG_CONFIG_HOME/hypr/terminal"

    run "$RUN_IN_TERMINAL" -e htop
    [ "$status" -eq 0 ]
    grep -qx 'alacritty -e htop' "$CALLS"
    ! grep -q -- '-e -e' "$CALLS"
}

@test "an unknown terminal is executed directly" {
    printf 'xterm\n' >"$XDG_CONFIG_HOME/hypr/terminal"
    cat >"$STUB_BIN/xterm" <<'EOF'
#!/usr/bin/env bash
printf '%s' "xterm" >>"$CALLS"
for a in "$@"; do printf ' %s' "$a" >>"$CALLS"; done
printf '\n' >>"$CALLS"
EOF
    chmod +x "$STUB_BIN/xterm"

    run "$RUN_IN_TERMINAL" htop
    [ "$status" -eq 0 ]
    grep -qx 'xterm htop' "$CALLS"
}
