#!/usr/bin/env bats
# Tests for config/hypr/scripts/controls.sh — the session toggles (DND, night
# light, caffeine, screen recording). Run with:
#
#   bats tests/
#
# The toggles own a marker under $XDG_CONFIG_HOME/hypr and talk to daemons
# through small CLIs (makoctl, swaync-client, hyprsunset, systemd-inhibit,
# wf-recorder). Everything external is stubbed on PATH and the daemon stubs stay
# alive so the PID markers can be observed; the real ~/.config and no real
# process is ever touched.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    CONTROLS="$REPO_ROOT/config/hypr/scripts/controls.sh"
    STATE_DIR="$BATS_TEST_TMPDIR/config/hypr"

    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$STATE_DIR" "$HOME/Videos"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUB_BIN"
    export STUB_BIN CALLS
    export PATH="$STUB_BIN:$PATH"

    # Each stub writes its line with one printf, so concurrent daemons cannot
    # interleave inside a line of the shared log.
    for tool in notify-send makoctl swaync-client pkill; do
        cat >"$STUB_BIN/$tool" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$tool \$*" >>"\$CALLS"
EOF
        chmod +x "$STUB_BIN/$tool"
    done

    # Daemon stubs: they log and stay alive, so the marker PID is meaningful
    # until the toggle stops them. wf-recorder answers SIGTERM as well as
    # SIGINT: a background job inherits SIGINT ignored, and the shell wrapper
    # cannot re-enable it.
    cat >"$STUB_BIN/hyprsunset" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "hyprsunset $*" >>"$CALLS"
while :; do sleep 1; done
EOF
    cat >"$STUB_BIN/systemd-inhibit" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "systemd-inhibit $*" >>"$CALLS"
while :; do sleep 1; done
EOF
    cat >"$STUB_BIN/wf-recorder" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "wf-recorder $*" >>"$CALLS"
trap 'printf "wf-recorder stop\n" >>"$CALLS"; exit 0' INT TERM
while :; do sleep 1; done
EOF
    chmod +x "$STUB_BIN/hyprsunset" "$STUB_BIN/systemd-inhibit" "$STUB_BIN/wf-recorder"

    cat >"$STUB_BIN/slurp" <<'EOF'
#!/usr/bin/env bash
printf '10,20 300x200\n'
EOF
    chmod +x "$STUB_BIN/slurp"
}

# stop_marker <file> — kill the process group / process recorded in a marker.
stop_marker() {
    local pid
    pid="$(cut -f1 "$1" 2>/dev/null || true)"
    [ -n "$pid" ] || return 0
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
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
    stop_marker "$STATE_DIR/night-light"
    stop_marker "$STATE_DIR/caffeine"
    stop_marker "$STATE_DIR/recording"
}

@test "status and indicators are empty when nothing is enabled" {
    run "$CONTROLS" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"dnd: выкл"* ]]
    [[ "$output" == *"night: выкл"* ]]
    [[ "$output" == *"caffeine: выкл"* ]]
    [[ "$output" == *"recording: выкл"* ]]

    run "$CONTROLS" indicators
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

# --- DND ---

@test "dnd on marks the state and applies the mako mode" {
    run "$CONTROLS" dnd on
    [ "$status" -eq 0 ]
    [ -e "$STATE_DIR/dnd" ]
    grep -qx 'makoctl mode -a do-not-disturb' "$CALLS"
    [ "$("$CONTROLS" get dnd)" = on ]
}

@test "dnd off clears the state and removes the mako mode" {
    : >"$STATE_DIR/dnd"

    run "$CONTROLS" dnd off
    [ "$status" -eq 0 ]
    [ ! -e "$STATE_DIR/dnd" ]
    grep -qx 'makoctl mode -r do-not-disturb' "$CALLS"
}

@test "a swaync marker drives swaync-client instead of makoctl" {
    printf 'swaync\n' >"$STATE_DIR/notifications"

    run "$CONTROLS" dnd toggle
    [ "$status" -eq 0 ]
    grep -qx 'swaync-client --dnd-on' "$CALLS"
    ! grep -q '^makoctl' "$CALLS"

    run "$CONTROLS" dnd toggle
    [ "$status" -eq 0 ]
    grep -qx 'swaync-client --dnd-off' "$CALLS"
}

# --- night light ---

@test "night on starts hyprsunset at the requested temperature" {
    run "$CONTROLS" night on 3500
    [ "$status" -eq 0 ]
    wait_for_call '^hyprsunset -t 3500$'
    [ "$("$CONTROLS" get night)" = on ]
    [ -s "$STATE_DIR/night-light" ]
}

@test "night refuses a temperature outside 1000..10000K" {
    run "$CONTROLS" night on 999
    [ "$status" -eq 2 ]
    [[ "$output" == *"вне диапазона"* ]]
    [ ! -e "$STATE_DIR/night-light" ]
}

@test "night refuses a non-numeric temperature" {
    run "$CONTROLS" night on warm
    [ "$status" -eq 2 ]
    [[ "$output" == *"целым числом"* ]]
    [ ! -e "$STATE_DIR/night-light" ]
}

@test "night off stops the daemon and clears the marker" {
    "$CONTROLS" night on 4000
    [ "$("$CONTROLS" get night)" = on ]

    run "$CONTROLS" night off
    [ "$status" -eq 0 ]
    [ "$("$CONTROLS" get night)" = off ]
    [ ! -e "$STATE_DIR/night-light" ]
    grep -qx 'pkill -x hyprsunset' "$CALLS"
}

# --- caffeine ---

@test "caffeine on holds an idle/sleep inhibitor and off releases it" {
    run "$CONTROLS" caffeine on
    [ "$status" -eq 0 ]
    wait_for_call 'systemd-inhibit --what=idle:sleep --who=gothic-dots'
    grep -qF 'sleep infinity' "$CALLS"
    [ "$("$CONTROLS" get caffeine)" = on ]

    run "$CONTROLS" caffeine off
    [ "$status" -eq 0 ]
    [ "$("$CONTROLS" get caffeine)" = off ]
    [ ! -e "$STATE_DIR/caffeine" ]
}

# --- screen recording ---

@test "record start records the full screen with audio and stop finalises it" {
    run "$CONTROLS" record start full audio
    [ "$status" -eq 0 ]
    [ -s "$STATE_DIR/recording" ]
    wait_for_call '^wf-recorder -f .*\.mp4 --audio$'
    [ "$("$CONTROLS" get recording)" = on ]

    run "$CONTROLS" record stop
    [ "$status" -eq 0 ]
    [ "$("$CONTROLS" get recording)" = off ]
    [ ! -e "$STATE_DIR/recording" ]
    grep -qx 'wf-recorder stop' "$CALLS"
}

@test "record start region passes the slurp geometry" {
    run "$CONTROLS" record start region
    [ "$status" -eq 0 ]
    wait_for_call ' -g 10,20 300x200'
}

@test "record start refuses a second concurrent recording" {
    "$CONTROLS" record start full

    run "$CONTROLS" record start full
    [ "$status" -eq 2 ]
    [[ "$output" == *"запись уже идёт"* ]]
}

# --- status, restore, reset ---

@test "indicators list only the active toggles" {
    "$CONTROLS" dnd on
    "$CONTROLS" caffeine on

    run "$CONTROLS" indicators
    [ "$status" -eq 0 ]
    [ "$output" = "DND · CAFFEINE" ]
}

@test "restore relaunches the daemons recorded by markers" {
    : >"$STATE_DIR/dnd"
    printf '999999\n' >"$STATE_DIR/night-light"
    printf '999999\n' >"$STATE_DIR/caffeine"

    run "$CONTROLS" restore
    [ "$status" -eq 0 ]
    grep -q '^makoctl mode -a do-not-disturb$' "$CALLS"
    wait_for_call '^hyprsunset -t 4000$'
    [ "$("$CONTROLS" get night)" = on ]
    [ "$("$CONTROLS" get caffeine)" = on ]
}

@test "reset turns every toggle off" {
    "$CONTROLS" dnd on
    "$CONTROLS" night on
    "$CONTROLS" caffeine on
    "$CONTROLS" record start full

    run "$CONTROLS" reset
    [ "$status" -eq 0 ]
    [ "$("$CONTROLS" get dnd)" = off ]
    [ "$("$CONTROLS" get night)" = off ]
    [ "$("$CONTROLS" get caffeine)" = off ]
    [ "$("$CONTROLS" get recording)" = off ]
    [ ! -e "$STATE_DIR/dnd" ]
    [ ! -e "$STATE_DIR/night-light" ]
    [ ! -e "$STATE_DIR/caffeine" ]
    [ ! -e "$STATE_DIR/recording" ]
}

@test "an unknown command prints usage and exits non-zero" {
    run "$CONTROLS" bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}

@test "get rejects an unknown toggle name" {
    run "$CONTROLS" get bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
