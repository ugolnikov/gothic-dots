#!/usr/bin/env bats
# Tests for config/hypr/scripts/battery.sh — one-shot check against a fake
# sysfs tree. No real battery, no daemon and no root.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    MODULE="$REPO_ROOT/config/hypr/scripts/battery.sh"
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    export GOTHIC_POWER_SUPPLY="$BATS_TEST_TMPDIR/power_supply"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME/hypr" "$GOTHIC_POWER_SUPPLY/BAT0"
    printf '80\n' >"$GOTHIC_POWER_SUPPLY/BAT0/capacity"
    printf 'Discharging\n' >"$GOTHIC_POWER_SUPPLY/BAT0/status"

    CALLS="$BATS_TEST_TMPDIR/calls.log"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"
    export CALLS STUB_BIN
    export PATH="$STUB_BIN:$PATH"

    cat >"$STUB_BIN/notify-send" <<'EOF'
#!/usr/bin/env bash
printf 'notify-send %s\n' "$*" >>"$CALLS"
EOF
    chmod +x "$STUB_BIN/notify-send"
}

battery() {
    printf '%s\n' "$1" >"$GOTHIC_POWER_SUPPLY/BAT0/capacity"
}

charge_state() {
    printf '%s\n' "$1" >"$GOTHIC_POWER_SUPPLY/BAT0/status"
}

@test "a healthy battery sends nothing" {
    battery 80

    run "$MODULE" check
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
    [ ! -e "$XDG_CONFIG_HOME/hypr/battery-notified" ]
}

@test "20% notifies once and does not repeat" {
    battery 15

    run "$MODULE" check
    [ "$status" -eq 0 ]
    grep -q '15%' "$CALLS"
    grep -qx '20' "$XDG_CONFIG_HOME/hypr/battery-notified"
    [ "$(grep -c 'notify-send' "$CALLS")" -eq 1 ]

    run "$MODULE" check
    [ "$status" -eq 0 ]
    [ "$(grep -c 'notify-send' "$CALLS")" -eq 1 ]
}

@test "dropping to 9% sends the 10% notice after the 20% one" {
    battery 15
    "$MODULE" check
    battery 9

    run "$MODULE" check
    [ "$status" -eq 0 ]
    [ "$(grep -c 'notify-send' "$CALLS")" -eq 2 ]
    grep -q '9%' "$CALLS"
}

@test "5% is critical, not three notices at once" {
    battery 4

    run "$MODULE" check
    [ "$status" -eq 0 ]
    [ "$(grep -c 'notify-send' "$CALLS")" -eq 1 ]
    grep -q 'critical' "$CALLS"
    grep -q '4%' "$CALLS"
}

@test "charging clears the thresholds" {
    battery 15
    "$MODULE" check
    [ -s "$XDG_CONFIG_HOME/hypr/battery-notified" ]

    charge_state Charging
    run "$MODULE" check
    [ "$status" -eq 0 ]
    [ ! -e "$XDG_CONFIG_HOME/hypr/battery-notified" ]
}

@test "a machine without a battery is silent" {
    rm -rf "$GOTHIC_POWER_SUPPLY/BAT0"

    run "$MODULE" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"батарея: нет"* ]]

    run "$MODULE" check
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "status shows capacity, state and notified thresholds" {
    battery 12
    printf 'Discharging\n' >"$GOTHIC_POWER_SUPPLY/BAT0/status"
    mkdir -p "$XDG_CONFIG_HOME/hypr"
    printf '20\n' >"$XDG_CONFIG_HOME/hypr/battery-notified"

    run "$MODULE" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"12% (Discharging)"* ]]
    [[ "$output" == *"отмечено: 20"* ]]
}

@test "an unknown action prints usage" {
    run "$MODULE" bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
