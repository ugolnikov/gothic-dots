#!/usr/bin/env bats
# Tests for config/hypr/scripts/ambience.sh — the time-of-day schedule. Run with:
#
#   bats tests/
#
# The clock is injected (AMBIENCE_NOW / AMBIENCE_EPOCH), the modules it drives
# (palette, controls, theme) are recorders on AMBIENCE_SCRIPTS, and the config
# lives in a throwaway file, so no test depends on the wall clock or a session.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    AMBIENCE="$REPO_ROOT/config/hypr/scripts/ambience.sh"
    MODS="$BATS_TEST_TMPDIR/mods"
    PICS="$BATS_TEST_TMPDIR/pics"

    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$XDG_CONFIG_HOME/hypr" "$HOME" "$MODS" "$PICS"

    CALLS="$BATS_TEST_TMPDIR/calls.log"
    export CALLS
    export AMBIENCE_SCRIPTS="$MODS"
    export AMBIENCE_CONF="$BATS_TEST_TMPDIR/ambience.conf"

    cat >"$MODS/palette.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "palette.sh $*" >>"$CALLS"
if [ "${1:-}" = status ]; then echo dark; fi
exit 0
EOF
    cat >"$MODS/controls.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "controls.sh $*" >>"$CALLS"
if [ "${1:-}" = get ]; then echo off; fi
exit 0
EOF
    cat >"$MODS/theme.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "theme.sh $*" >>"$CALLS"
EOF
    cat >"$BATS_TEST_TMPDIR/notify-send" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MODS"/* "$BATS_TEST_TMPDIR/notify-send"
    export PATH="$BATS_TEST_TMPDIR:$PATH"

    write_config
}

write_config() {
    cat >"$AMBIENCE_CONF" <<'EOF'
day_start=07:30
evening_start=19:00
night_start=22:30
day_palette=dark
evening_palette=dynamic
night_palette=dark
night_temp=3500
night_light=auto
dnd=auto
EOF
}

enable_rotation() {
    cat >>"$AMBIENCE_CONF" <<EOF
rotate_dir=$PICS
rotate_interval=60
rotate_order=sequential
EOF
}

@test "status names the slot at different times of day" {
    export AMBIENCE_NOW=08:00
    run "$AMBIENCE" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"слот: day (07:30–19:00)"* ]]
    [[ "$output" == *"следующая граница: 19:00"* ]]

    export AMBIENCE_NOW=20:00
    run "$AMBIENCE" status
    [[ "$output" == *"слот: evening (19:00–22:30)"* ]]
    [[ "$output" == *"следующая граница: 22:30"* ]]

    export AMBIENCE_NOW=23:30
    run "$AMBIENCE" status
    [[ "$output" == *"слот: night (22:30–07:30)"* ]]
    [[ "$output" == *"следующая граница: 07:30"* ]]

    export AMBIENCE_NOW=03:00
    run "$AMBIENCE" status
    [[ "$output" == *"слот: night"* ]]
}

@test "status reports the master switch and the driven modules" {
    : >"$XDG_CONFIG_HOME/hypr/ambience"
    export AMBIENCE_NOW=08:00

    run "$AMBIENCE" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"ambience: вкл"* ]]
    [[ "$output" == *"палитра: dark"* ]]
    [[ "$output" == *"ночной свет: off, dnd: off"* ]]
    [[ "$output" == *"обои: ротация выключена"* ]]
}

@test "a tick applies the day slot and records it" {
    : >"$XDG_CONFIG_HOME/hypr/ambience"

    run "$AMBIENCE" tick --at 08:00
    [ "$status" -eq 0 ]
    grep -qx 'palette.sh set dark' "$CALLS"
    grep -qx 'controls.sh night off 3500' "$CALLS"
    grep -qx 'controls.sh dnd off' "$CALLS"
    [ "$(cat "$XDG_CONFIG_HOME/hypr/ambience-slot")" = day ]
}

@test "a second tick in the same slot does nothing" {
    : >"$XDG_CONFIG_HOME/hypr/ambience"
    "$AMBIENCE" tick --at 08:00
    : >"$CALLS"

    run "$AMBIENCE" tick --at 08:05
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "the evening slot uses the wallpaper palette" {
    : >"$XDG_CONFIG_HOME/hypr/ambience"

    run "$AMBIENCE" tick --at 20:00
    [ "$status" -eq 0 ]
    grep -qx 'palette.sh set dynamic' "$CALLS"
    grep -qx 'controls.sh night off 3500' "$CALLS"
    grep -qx 'controls.sh dnd off' "$CALLS"
}

@test "the night slot turns the light and DND on" {
    : >"$XDG_CONFIG_HOME/hypr/ambience"

    run "$AMBIENCE" tick --at 23:00
    [ "$status" -eq 0 ]
    grep -qx 'palette.sh set dark' "$CALLS"
    grep -qx 'controls.sh night on 3500' "$CALLS"
    grep -qx 'controls.sh dnd on' "$CALLS"
}

@test "with the master switch off a tick changes nothing" {
    run "$AMBIENCE" tick --at 23:00
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
    [ ! -e "$XDG_CONFIG_HOME/hypr/ambience-slot" ]
}

@test "dry run prints the plan and writes nothing" {
    : >"$XDG_CONFIG_HOME/hypr/ambience"

    run "$AMBIENCE" tick --at 20:00 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"palette.sh set dynamic"* ]]
    [[ "$output" == *"controls.sh night off 3500"* ]]
    [[ "$output" == *"ничего не изменено"* ]]
    [ ! -s "$CALLS" ]
    [ ! -e "$XDG_CONFIG_HOME/hypr/ambience-slot" ]
}

@test "on applies the current slot, off clears the switch" {
    export AMBIENCE_NOW=08:00

    run "$AMBIENCE" on
    [ "$status" -eq 0 ]
    [ -e "$XDG_CONFIG_HOME/hypr/ambience" ]
    grep -qx 'palette.sh set dark' "$CALLS"

    run "$AMBIENCE" off
    [ "$status" -eq 0 ]
    [ ! -e "$XDG_CONFIG_HOME/hypr/ambience" ]
    [ ! -e "$XDG_CONFIG_HOME/hypr/ambience-slot" ]
}

@test "config validation rejects boundaries out of order" {
    cat >"$AMBIENCE_CONF" <<'EOF'
day_start=20:00
evening_start=19:00
night_start=22:30
EOF

    run "$AMBIENCE" tick --at 08:00
    [ "$status" -eq 2 ]
    [[ "$output" == *"по возрастанию"* ]]
}

@test "rotation picks the first wallpaper and then the next one" {
    enable_rotation
    : >"$XDG_CONFIG_HOME/hypr/ambience"
    : >"$PICS/a.png"
    : >"$PICS/b.png"

    AMBIENCE_EPOCH=100000 run "$AMBIENCE" tick --at 08:00
    [ "$status" -eq 0 ]
    grep -qx "theme.sh $PICS/a.png" "$CALLS"
    [ "$(cat "$XDG_CONFIG_HOME/hypr/ambience-wall")" = "$PICS/a.png" ]

    AMBIENCE_EPOCH=100100 run "$AMBIENCE" tick --at 08:05
    [ "$status" -eq 0 ]
    grep -qx "theme.sh $PICS/b.png" "$CALLS"
    [ "$(cat "$XDG_CONFIG_HOME/hypr/ambience-wall")" = "$PICS/b.png" ]
}

@test "rotation waits for its interval" {
    enable_rotation
    : >"$XDG_CONFIG_HOME/hypr/ambience"
    : >"$PICS/a.png"

    AMBIENCE_EPOCH=100000 "$AMBIENCE" tick --at 08:00
    : >"$CALLS"

    AMBIENCE_EPOCH=100030 run "$AMBIENCE" tick --at 08:01
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "next rotates on demand even when the schedule is off" {
    enable_rotation
    : >"$PICS/a.png"
    : >"$PICS/b.png"

    AMBIENCE_EPOCH=200000 run "$AMBIENCE" next
    [ "$status" -eq 0 ]
    grep -qx "theme.sh $PICS/a.png" "$CALLS"
    [ ! -e "$XDG_CONFIG_HOME/hypr/ambience" ]
}

@test "a missing wallpaper directory is not fatal" {
    enable_rotation
    rmdir "$PICS"
    : >"$XDG_CONFIG_HOME/hypr/ambience"

    run "$AMBIENCE" tick --at 08:00
    [ "$status" -eq 0 ]
    [[ "$output" == *"нет каталога обоев"* ]]
}

@test "config prints the effective values" {
    run "$AMBIENCE" config
    [ "$status" -eq 0 ]
    [[ "$output" == *"evening_palette=dynamic"* ]]
    [[ "$output" == *"night_light=auto"* ]]
    [[ "$output" == *"rotate_interval=1800"* ]]
}

@test "an unknown command prints usage" {
    run "$AMBIENCE" bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
