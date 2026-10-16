#!/usr/bin/env bats
# Tests for config/hypr/scripts/filemanager.sh (SUPER + E). Run with:
#
#   bats tests/
#
# The wrapper execs the first available GUI file manager (nautilus, thunar,
# nemo, pcmanfm) and otherwise falls back to yazi in the chosen terminal. It
# execs, so it is run as a subprocess and the stubs record themselves. The
# fallback runs the real run-in-terminal.sh, linked into a throwaway config
# tree, so nothing real is launched.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    FILEMANAGER="$REPO_ROOT/config/hypr/scripts/filemanager.sh"

    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    mkdir -p "$XDG_CONFIG_HOME/hypr/scripts"

    # The fallback execs "$XDG_CONFIG_HOME/hypr/scripts/run-in-terminal.sh":
    # link the real one so the fallback seam is exercised for real.
    ln -s "$REPO_ROOT/config/hypr/scripts/run-in-terminal.sh" \
        "$XDG_CONFIG_HOME/hypr/scripts/run-in-terminal.sh"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUB_BIN"
    export STUB_BIN CALLS
    export PATH="$STUB_BIN:$PATH"

    stub() {
        cat >"$STUB_BIN/$1" <<EOF
#!/usr/bin/env bash
printf '%s' "$1" >>"\$CALLS"
for a in "\$@"; do printf ' %s' "\$a" >>"\$CALLS"; done
printf '\n' >>"\$CALLS"
EOF
        chmod +x "$STUB_BIN/$1"
    }
    for tool in nautilus thunar nemo pcmanfm footclient foot; do
        stub "$tool"
    done
}

@test "nautilus wins when every GUI file manager is present" {
    run "$FILEMANAGER"
    [ "$status" -eq 0 ]
    grep -qx 'nautilus' "$CALLS"
    ! grep -q '^thunar' "$CALLS"
}

@test "thunar is chosen when nautilus is absent" {
    rm -f "$STUB_BIN/nautilus"

    run "$FILEMANAGER"
    [ "$status" -eq 0 ]
    grep -qx 'thunar' "$CALLS"
}

@test "pcmanfm is chosen when it is the only GUI file manager" {
    rm -f "$STUB_BIN/nautilus" "$STUB_BIN/thunar" "$STUB_BIN/nemo"

    run "$FILEMANAGER"
    [ "$status" -eq 0 ]
    grep -qx 'pcmanfm' "$CALLS"
}

@test "with no GUI file manager it falls back to yazi in the terminal" {
    rm -f "$STUB_BIN/nautilus" "$STUB_BIN/thunar" "$STUB_BIN/nemo" "$STUB_BIN/pcmanfm"
    printf 'foot\n' >"$XDG_CONFIG_HOME/hypr/terminal"

    run "$FILEMANAGER"
    [ "$status" -eq 0 ]
    grep -qx 'footclient yazi' "$CALLS"
}

@test "the file manager receives the wrapper's arguments" {
    rm -f "$STUB_BIN/nautilus" "$STUB_BIN/thunar" "$STUB_BIN/nemo"

    run "$FILEMANAGER" /tmp
    [ "$status" -eq 0 ]
    grep -qx 'pcmanfm /tmp' "$CALLS"
}
