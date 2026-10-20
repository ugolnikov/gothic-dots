#!/usr/bin/env bats
# Tests for config/hypr/scripts/eventd.sh — window rules, the screen-share DND
# round trip and the monitor/fullscreen hooks. Run with:
#
#   bats tests/
#
# Events are fed with `handle`, so no socket is needed; hyprctl and controls are
# stubs, hooks are recorder scripts, and the config tree is a throwaway.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    EVENTD="$REPO_ROOT/config/hypr/scripts/eventd.sh"
    STATE_DIR="$BATS_TEST_TMPDIR/config/hypr"
    MODS="$BATS_TEST_TMPDIR/mods"
    HOOKS="$STATE_DIR/eventd.d"

    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    export EVENTD_SCRIPTS="$MODS"
    export EVENTD_RULES="$STATE_DIR/windowrules.tsv"
    export EVENTD_CONF="$STATE_DIR/eventd.conf"
    export EVENTD_HOOKS="$HOOKS"
    unset HYPRLAND_INSTANCE_SIGNATURE
    mkdir -p "$HOME" "$STATE_DIR" "$MODS" "$HOOKS"

    CALLS="$BATS_TEST_TMPDIR/calls.log"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"
    export CALLS STATE_DIR
    export PATH="$STUB_BIN:$PATH"

    cat >"$STUB_BIN/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf 'hyprctl %s\n' "$*" >>"$CALLS"
EOF
    cat >"$MODS/controls.sh" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    get) cat "$STATE_DIR/$2" 2>/dev/null || echo off ;;
    dnd | caffeine) printf '%s\n' "$2" >"$STATE_DIR/$1" ;;
esac
exit 0
EOF
    cat >"$STUB_BIN/notify-send" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    cat >"$MODS/keyboard-memory.sh" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    restore) printf 'keyboard restore %s\n' "$2" >>"$CALLS" ;;
    remember-active) printf 'keyboard remember %s\n' "$2" >>"$CALLS" ;;
    status) printf 'память раскладок: тест\nзаписей: 0\n' ;;
esac
exit 0
EOF
    chmod +x "$STUB_BIN"/* "$MODS"/*

    printf 'off\n' >"$STATE_DIR/dnd"
    printf 'on\n' >"$STATE_DIR/caffeine"

    cat >"$EVENTD_RULES" <<'EOF'
# class<TAB>workspace
firefox	2
EOF
    cat >"$EVENTD_CONF" <<'EOF'
share_classes=portal*,org.gnome.ScreenShare
EOF

    for hook in monitor-added monitor-removed fullscreen-on fullscreen-off; do
        cat >"$HOOKS/$hook.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$hook \$*" >>"\$CALLS"
EOF
        chmod +x "$HOOKS/$hook.sh"
    done
}

@test "a matching window rule moves the window" {
    run "$EVENTD" handle 'openwindow>>0xabc,1,firefox,My Title, with comma'
    [ "$status" -eq 0 ]
    grep -qx 'hyprctl dispatch movetoworkspacesilent 2,address:0xabc' "$CALLS"
}

@test "an unknown class is left alone" {
    run "$EVENTD" handle 'openwindow>>0xdef,1,foot,term'
    [ "$status" -eq 0 ]
    ! grep -q '^hyprctl dispatch' "$CALLS"
}

@test "a share window turns DND on and caffeine off" {
    run "$EVENTD" handle 'openwindow>>0x5aa,1,portal-gnome,Share'
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE_DIR/dnd")" = on ]
    [ "$(cat "$STATE_DIR/caffeine")" = off ]
    grep -qx 'addr=0x5aa' "$STATE_DIR/eventd-share"
    grep -qx 'dnd=off' "$STATE_DIR/eventd-share"
    grep -qx 'caffeine=on' "$STATE_DIR/eventd-share"
}

@test "a second share window does not overwrite the saved state" {
    "$EVENTD" handle 'openwindow>>0x5aa,1,portal-gnome,Share'
    : >"$CALLS"

    run "$EVENTD" handle 'openwindow>>0x5bb,1,portal-kde,Share 2'
    [ "$status" -eq 0 ]
    grep -qx 'addr=0x5aa' "$STATE_DIR/eventd-share"
    ! grep -q '^hyprctl dispatch' "$CALLS"
}

@test "closing the share window restores the previous DND and caffeine" {
    "$EVENTD" handle 'openwindow>>0x5aa,1,portal-gnome,Share'

    run "$EVENTD" handle 'closewindow>>0x5bb'
    [ "$status" -eq 0 ]
    [ -e "$STATE_DIR/eventd-share" ]

    run "$EVENTD" handle 'closewindow>>0x5aa'
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE_DIR/dnd")" = off ]
    [ "$(cat "$STATE_DIR/caffeine")" = on ]
    [ ! -e "$STATE_DIR/eventd-share" ]
}

@test "monitor events run their hooks with the monitor name" {
    run "$EVENTD" handle 'monitoradded>>DP-1'
    [ "$status" -eq 0 ]
    grep -qx 'monitor-added DP-1' "$CALLS"

    run "$EVENTD" handle 'monitorremoved>>DP-1'
    [ "$status" -eq 0 ]
    grep -qx 'monitor-removed DP-1' "$CALLS"
}

@test "fullscreen events pick the on/off hook" {
    run "$EVENTD" handle 'fullscreen>>0xabc,1'
    [ "$status" -eq 0 ]
    grep -qx 'fullscreen-on 0xabc' "$CALLS"

    run "$EVENTD" handle 'fullscreen>>0xabc,0'
    [ "$status" -eq 0 ]
    grep -qx 'fullscreen-off 0xabc' "$CALLS"
}

@test "activewindow restores the keyboard memory for its class" {
    run "$EVENTD" handle 'activewindow>>firefox,Title, with comma'
    [ "$status" -eq 0 ]
    grep -qx 'keyboard restore firefox' "$CALLS"
}

@test "activelayout remembers the layout for the active class" {
    run "$EVENTD" handle 'activelayout>>kbd,Russian'
    [ "$status" -eq 0 ]
    grep -qx 'keyboard remember Russian' "$CALLS"
}

@test "run --fake replays a file of events" {
    cat >"$BATS_TEST_TMPDIR/events" <<'EOF'
openwindow>>0xabc,1,firefox,Title
monitoradded>>HDMI-A-1
EOF

    run "$EVENTD" run --fake "$BATS_TEST_TMPDIR/events"
    [ "$status" -eq 0 ]
    grep -qx 'hyprctl dispatch movetoworkspacesilent 2,address:0xabc' "$CALLS"
    grep -qx 'monitor-added HDMI-A-1' "$CALLS"
}

@test "malformed and unknown events are ignored" {
    run "$EVENTD" handle 'garbage'
    [ "$status" -eq 0 ]
    run "$EVENTD" handle 'someevent>>nothing'
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "status reports the configuration" {
    run "$EVENTD" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"правила: $EVENTD_RULES"* ]]
    [[ "$output" == *"шаринг: portal*"* ]]
    [[ "$output" == *"хуки: $HOOKS"* ]]
}

@test "run without a Hyprland socket fails loudly" {
    run "$EVENTD" run
    [ "$status" -eq 2 ]
    [[ "$output" == *"HYPRLAND_INSTANCE_SIGNATURE"* ]]
}
