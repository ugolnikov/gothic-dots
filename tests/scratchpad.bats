#!/usr/bin/env bats
# Tests for config/hypr/scripts/scratchpad.sh — named dropdowns backed by
# special workspaces. hyprctl is a stub serving clients JSON and recording
# dispatches; rofi returns ROFI_CHOICE.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    MODULE="$REPO_ROOT/config/hypr/scripts/scratchpad.sh"
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    STATE="$XDG_CONFIG_HOME/hypr"
    mkdir -p "$STATE" "$HOME"
    export SCRATCHPAD_CONF="$STATE/scratchpads.tsv"

    cat >"$SCRATCHPAD_CONF" <<'EOF'
# name	class	command
term	foot	foot
music	pavucontrol	pavucontrol
EOF

    CALLS="$BATS_TEST_TMPDIR/calls.log"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"
    export CALLS STUB_BIN
    export PATH="$STUB_BIN:$PATH"
    export SCRATCHPAD_DELAY=0

    CLIENTS_JSON="$BATS_TEST_TMPDIR/clients.json"
    export CLIENTS_JSON
    printf '[]\n' >"$CLIENTS_JSON"

    cat >"$STUB_BIN/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    "clients -j") cat "$CLIENTS_JSON" ;;
    dispatch\ *) printf 'hyprctl %s\n' "$*" >>"$CALLS" ;;
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

@test "a stopped scratchpad is spawned in its special workspace" {
    run "$MODULE" toggle term
    [ "$status" -eq 0 ]
    grep -qxF 'hyprctl dispatch exec [workspace special:term] foot' "$CALLS"
    grep -qx 'hyprctl dispatch togglespecialworkspace term' "$CALLS"
}

@test "a window already in the special workspace is only toggled" {
    cat >"$CLIENTS_JSON" <<'EOF'
[{"class":"foot","address":"0x1","workspace":{"name":"special:term"}}]
EOF

    run "$MODULE" toggle term
    [ "$status" -eq 0 ]
    grep -qx 'hyprctl dispatch togglespecialworkspace term' "$CALLS"
    ! grep -q 'movetoworkspacesilent' "$CALLS"
    ! grep -q 'dispatch exec' "$CALLS"
}

@test "a window of the class elsewhere is moved, not duplicated" {
    cat >"$CLIENTS_JSON" <<'EOF'
[{"class":"pavucontrol","address":"0x2","workspace":{"name":"3"}}]
EOF

    run "$MODULE" toggle music
    [ "$status" -eq 0 ]
    grep -qx 'hyprctl dispatch movetoworkspacesilent special:music,address:0x2' "$CALLS"
    grep -qx 'hyprctl dispatch togglespecialworkspace music' "$CALLS"
    ! grep -q 'dispatch exec' "$CALLS"
}

@test "an unknown name fails with a notification" {
    run "$MODULE" toggle nope
    [ "$status" -eq 1 ]
    grep -q 'notify-send' "$CALLS"
    ! grep -q 'dispatch' "$CALLS"
}

@test "the menu passes the chosen name to toggle" {
    export ROFI_CHOICE=music

    run "$MODULE" menu
    [ "$status" -eq 0 ]
    grep -qxF 'hyprctl dispatch exec [workspace special:music] pavucontrol' "$CALLS"
}

@test "list and status report the config" {
    run "$MODULE" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"term — foot"* ]]
    [[ "$output" == *"music — pavucontrol"* ]]

    run "$MODULE" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"записей: 2"* ]]
}

@test "a missing config fails cleanly" {
    rm -f "$SCRATCHPAD_CONF"

    run "$MODULE" toggle term
    [ "$status" -eq 1 ]
    grep -q 'notify-send' "$CALLS"
}

@test "an unknown action prints usage" {
    run "$MODULE" bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
