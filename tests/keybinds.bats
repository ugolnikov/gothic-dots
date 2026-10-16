#!/usr/bin/env bats
# Tests for the keybind cheatsheet (config/hypr/scripts/keybinds.sh). Run with:
#
#   bats tests/
#
# The cheatsheet renders config/hypr/keybinds.tsv into rofi. These tests drive
# it against a throwaway config tree with rofi (and notify-send) stubbed on
# PATH, so the real ~/.config is never read.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    KEYBINDS="$REPO_ROOT/config/hypr/scripts/keybinds.sh"

    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$XDG_CONFIG_HOME/hypr" "$HOME"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"
    ROFI_ARGS="$BATS_TEST_TMPDIR/rofi.args"
    ROFI_INPUT="$BATS_TEST_TMPDIR/rofi.input"
    NOTIFY_LOG="$BATS_TEST_TMPDIR/notify.log"
    export ROFI_ARGS ROFI_INPUT NOTIFY_LOG
    export PATH="$STUB_BIN:$PATH"

    # rofi records the arguments it was handed and its input, so a test can
    # assert the rendered cheatsheet line by line.
    cat >"$STUB_BIN/rofi" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$ROFI_ARGS"
cat >"$ROFI_INPUT"
EOF
    chmod +x "$STUB_BIN/rofi"

    cat >"$STUB_BIN/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NOTIFY_LOG"
EOF
    chmod +x "$STUB_BIN/notify-send"
}

@test "keybinds renders the table without backticks, keys and actions intact" {
    cat >"$XDG_CONFIG_HOME/hypr/keybinds.tsv" <<'EOF'
# comment — ignored
`SUPER + A`	alpha action
`SUPER + B` / `SUPER + C`	beta action
EOF

    run "$KEYBINDS"
    [ "$status" -eq 0 ]
    [ -f "$ROFI_INPUT" ]
    grep -q 'SUPER + A' "$ROFI_INPUT"
    grep -q 'alpha action' "$ROFI_INPUT"
    grep -q 'SUPER + B / SUPER + C' "$ROFI_INPUT"
    grep -q 'beta action' "$ROFI_INPUT"
    ! grep -q '`' "$ROFI_INPUT"
    ! grep -q 'comment' "$ROFI_INPUT"
}

# The key column is padded to the widest key so the em-dash separators line up:
# the short key must be followed by more than one space before its action.
@test "keybinds aligns the actions on the widest key" {
    cat >"$XDG_CONFIG_HOME/hypr/keybinds.tsv" <<'EOF'
`SUPER + A`	alpha action
`SUPER + B / SUPER + C`	beta action
EOF

    run "$KEYBINDS"
    [ "$status" -eq 0 ]
    grep -Eq 'SUPER \+ A +— alpha action' "$ROFI_INPUT"
}

@test "keybinds prompts with the Клавиши label and the settings theme" {
    cat >"$XDG_CONFIG_HOME/hypr/keybinds.tsv" <<'EOF'
`SUPER + A`	alpha action
EOF

    run "$KEYBINDS"
    [ "$status" -eq 0 ]
    [[ "$(cat "$ROFI_ARGS")" == *"-p Клавиши"* ]]
    [[ "$(cat "$ROFI_ARGS")" == *"rofi/settings.rasi"* ]]
}

@test "keybinds reports a missing table without failing or opening rofi" {
    rm -f "$XDG_CONFIG_HOME/hypr/keybinds.tsv"

    run "$KEYBINDS"
    [ "$status" -eq 0 ]
    grep -q 'нет' "$NOTIFY_LOG"
    [ ! -f "$ROFI_INPUT" ]
}
