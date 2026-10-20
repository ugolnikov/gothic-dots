#!/usr/bin/env bats
# Tests for config/hypr/scripts/quick.sh — the rofi quick panel. Run with:
#
#   bats tests/
#
# quick.sh is only a view: it asks controls.sh for each state and passes the
# chosen row back to it. The real controls.sh is linked into a throwaway
# XDG_CONFIG_HOME, rofi is stubbed to return ROFI_CHOICE, and the notification
# daemon is stubbed, so no real session is needed.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    QUICK="$REPO_ROOT/config/hypr/scripts/quick.sh"
    CTL="$REPO_ROOT/config/hypr/scripts/controls.sh"
    CONFIG="$BATS_TEST_TMPDIR/config"
    STATE_DIR="$CONFIG/hypr"

    export XDG_CONFIG_HOME="$CONFIG"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$STATE_DIR/scripts" "$HOME/Videos"
    ln -s "$CTL" "$STATE_DIR/scripts/controls.sh"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    export STUB_BIN CALLS
    export PATH="$STUB_BIN:$PATH"

    cat >"$STUB_BIN/rofi" <<'EOF'
#!/usr/bin/env bash
input="$(cat)"
if [ -n "${ROFI_CHOICE:-}" ]; then
    printf '%s\n' "$input" | grep -m1 -F -- "$ROFI_CHOICE" || true
fi
EOF
    chmod +x "$STUB_BIN/rofi"

    for tool in notify-send makoctl pkill; do
        cat >"$STUB_BIN/$tool" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$tool \$*" >>"\$CALLS"
EOF
        chmod +x "$STUB_BIN/$tool"
    done
    cat >"$STUB_BIN/hyprsunset" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "hyprsunset $*" >>"$CALLS"
while :; do sleep 1; done
EOF
    chmod +x "$STUB_BIN/hyprsunset"
}


# wait_for_call <pattern> — daemon stubs log from a background process, so the
# call may land just after the toggle returns; poll briefly instead of racing.
wait_for_call() {
    local pattern="$1" i
    for i in {1..50}; do
        grep -q -- "$pattern" "$CALLS" 2>/dev/null && return 0
        sleep 0.1
    done
    return 1
}

teardown() {
    local pid
    for f in "$STATE_DIR/night-light" "$STATE_DIR/recording"; do
        pid="$(cut -f1 "$f" 2>/dev/null || true)"
        [ -n "$pid" ] || continue
        kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
    done
}

@test "the list shows every toggle off and both recording actions" {
    run "$QUICK" --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"○ Не беспокоить"* ]]
    [[ "$output" == *"○ Ночной свет"* ]]
    [[ "$output" == *"○ Кофеин"* ]]
    [[ "$output" == *"Записать экран (полный, со звуком)"* ]]
    [[ "$output" == *"Записать область (со звуком)"* ]]
    [[ "$output" == *"Настройки"* ]]
    [[ "$output" == *"Питание"* ]]
}

@test "the list marks the toggles that are on" {
    : >"$STATE_DIR/dnd"
    sleep 300 &
    printf '%s\n' "$!" >"$STATE_DIR/night-light"

    run "$QUICK" --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"● Не беспокоить"* ]]
    [[ "$output" == *"● Ночной свет"* ]]
}

@test "an active recording replaces the start rows with stop" {
    sleep 300 &
    local pid=$!
    printf '%s\t%s\n' "$pid" "$HOME/Videos/recording.mp4" >"$STATE_DIR/recording"

    run "$QUICK" --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"● Остановить запись"* ]]
    [[ "$output" != *"Записать экран"* ]]
    [[ "$output" != *"Записать область"* ]]
}

@test "choosing DND toggles it through controls.sh" {
    export ROFI_CHOICE="○ Не беспокоить"

    run "$QUICK"
    [ "$status" -eq 0 ]
    [ -e "$STATE_DIR/dnd" ]
    grep -qx 'makoctl mode -a do-not-disturb' "$CALLS"
}

@test "choosing night light starts hyprsunset through controls.sh" {
    export ROFI_CHOICE="○ Ночной свет"

    run "$QUICK"
    [ "$status" -eq 0 ]
    wait_for_call '^hyprsunset -t 4000$'
}

@test "escape changes nothing" {
    run "$QUICK"
    [ "$status" -eq 0 ]
    [ ! -e "$STATE_DIR/dnd" ]
    [ ! -e "$STATE_DIR/night-light" ]
    [ ! -s "$CALLS" ]
}

@test "an unknown argument prints usage and exits non-zero" {
    run "$QUICK" bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
