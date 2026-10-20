#!/usr/bin/env bats
# Tests for bin/gothic — the single CLI over the desktop modules. Run with:
#
#   bats tests/
#
# gothic is a router: every subcommand must reach the module that owns the
# state and return its exit code. The modules are recorder stubs in a throwaway
# script directory (GOTHIC_SCRIPTS), so the tests assert the routing itself and
# never touch a real session.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    GOTHIC="$REPO_ROOT/bin/gothic"
    MODS="$BATS_TEST_TMPDIR/mods"

    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    mkdir -p "$XDG_CONFIG_HOME" "$MODS" "$HOME"

    CALLS="$BATS_TEST_TMPDIR/calls.log"
    export CALLS
    export GOTHIC_SCRIPTS="$MODS"
    export GOTHIC_DOCTOR="$BATS_TEST_TMPDIR/doctor"

    cat >"$MODS/palette.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "palette.sh $*" >>"$CALLS"
if [ "${1:-}" = status ]; then echo dark; fi
exit 0
EOF
    cat >"$MODS/theme-mode.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "theme-mode.sh $*" >>"$CALLS"
EOF
    cat >"$MODS/controls.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "controls.sh $*" >>"$CALLS"
case "${1:-}" in
    status) printf 'dnd: выкл\nnight: выкл\ncaffeine: выкл\nrecording: выкл\n' ;;
    get) echo off ;;
esac
EOF
    cat >"$MODS/session.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "session.sh $*" >>"$CALLS"
if [ "${1:-}" = list ]; then echo work; fi
[ "${1:-}" = count ] && { echo 1; exit 0; }
exit 0
EOF
    for m in wallpaper.sh wallpaper-picker.sh keybinds.sh settings.sh launcher.sh quick.sh ambience.sh preset.sh eventd.sh; do
        cat >"$MODS/$m" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "__NAME__${*:+ $*}" >>"$CALLS"
EOF
        sed -i "s/__NAME__/$m/" "$MODS/$m"
    done
    cat >"$BATS_TEST_TMPDIR/doctor" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "doctor${*:+ $*}" >>"$CALLS"
EOF
    chmod +x "$MODS"/* "$BATS_TEST_TMPDIR/doctor"
}

@test "status shows the palette, every toggle and the session count" {
    run "$GOTHIC"
    [ "$status" -eq 0 ]
    [[ "$output" == *"палитра: dark"* ]]
    [[ "$output" == *"dnd: выкл"* ]]
    [[ "$output" == *"сессии: 1"* ]]
}

@test "toggle is routed to controls.sh with the named action" {
    run "$GOTHIC" toggle dnd on
    [ "$status" -eq 0 ]
    grep -qx 'controls.sh dnd on' "$CALLS"
}

@test "toggle defaults to toggle" {
    run "$GOTHIC" toggle night
    [ "$status" -eq 0 ]
    grep -qx 'controls.sh night toggle' "$CALLS"
}

@test "toggle record maps on/off to start/stop" {
    run "$GOTHIC" toggle record on
    [ "$status" -eq 0 ]
    grep -qx 'controls.sh record start' "$CALLS"

    run "$GOTHIC" toggle record off
    [ "$status" -eq 0 ]
    grep -qx 'controls.sh record stop' "$CALLS"
}

@test "toggle rejects an unknown name" {
    run "$GOTHIC" toggle bogus on
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}

@test "theme routes set, status and the dark/light toggle" {
    run "$GOTHIC" theme light
    [ "$status" -eq 0 ]
    grep -qx 'palette.sh set light' "$CALLS"

    run "$GOTHIC" theme
    [ "$status" -eq 0 ]
    [ "$output" = dark ]
    grep -qx 'palette.sh status' "$CALLS"

    run "$GOTHIC" theme toggle
    [ "$status" -eq 0 ]
    grep -qx 'theme-mode.sh toggle' "$CALLS"
}

@test "theme rejects an unknown mode" {
    run "$GOTHIC" theme neon
    [ "$status" -eq 2 ]
}

@test "wall routes pick and an explicit file" {
    run "$GOTHIC" wall pick
    [ "$status" -eq 0 ]
    grep -qx 'wallpaper-picker.sh' "$CALLS"

    file="$BATS_TEST_TMPDIR/wall.png"
    : >"$file"
    run "$GOTHIC" wall "$file"
    [ "$status" -eq 0 ]
    grep -qx "wallpaper.sh $file" "$CALLS"
}

@test "wall refuses a missing file and says rotation is not implemented" {
    run "$GOTHIC" wall "$BATS_TEST_TMPDIR/nope.png"
    [ "$status" -eq 2 ]
    [[ "$output" == *"нет файла обоев"* ]]

    run "$GOTHIC" wall next
    [ "$status" -eq 1 ]
    [[ "$output" == *"ambience"* ]]
}

@test "session passes the subcommand and its arguments through" {
    run "$GOTHIC" session save work
    [ "$status" -eq 0 ]
    grep -qx 'session.sh save work' "$CALLS"

    run "$GOTHIC" session restore work --dry-run
    [ "$status" -eq 0 ]
    grep -qx 'session.sh restore work --dry-run' "$CALLS"

    run "$GOTHIC" session
    [ "$status" -eq 0 ]
    [ "$output" = work ]
}

@test "record maps status/get and start arguments" {
    run "$GOTHIC" record
    [ "$status" -eq 0 ]
    [ "$output" = off ]
    grep -qx 'controls.sh get recording' "$CALLS"

    run "$GOTHIC" record start region audio
    [ "$status" -eq 0 ]
    grep -qx 'controls.sh record start region audio' "$CALLS"

    run "$GOTHIC" record stop
    [ "$status" -eq 0 ]
    grep -qx 'controls.sh record stop' "$CALLS"
}

@test "eventd is routed to its module" {
    run "$GOTHIC" eventd
    [ "$status" -eq 0 ]
    grep -qx 'eventd.sh status' "$CALLS"

    run "$GOTHIC" eventd run
    [ "$status" -eq 0 ]
    grep -qx 'eventd.sh run' "$CALLS"
}

@test "preset is routed to its module" {
    run "$GOTHIC" preset list
    [ "$status" -eq 0 ]
    grep -qx 'preset.sh list' "$CALLS"

    run "$GOTHIC" preset
    [ "$status" -eq 0 ]
    grep -qx 'preset.sh current' "$CALLS"
}

@test "ambience is routed to its module" {
    run "$GOTHIC" ambience toggle
    [ "$status" -eq 0 ]
    grep -qx 'ambience.sh toggle' "$CALLS"

    run "$GOTHIC" ambience
    [ "$status" -eq 0 ]
    grep -qx 'ambience.sh status' "$CALLS"
}

@test "the remaining commands reach their scripts" {
    run "$GOTHIC" keybinds
    [ "$status" -eq 0 ]
    grep -qx 'keybinds.sh' "$CALLS"

    run "$GOTHIC" settings
    [ "$status" -eq 0 ]
    grep -qx 'settings.sh' "$CALLS"

    run "$GOTHIC" menu
    [ "$status" -eq 0 ]
    grep -qx 'launcher.sh menu' "$CALLS"

    run "$GOTHIC" doctor
    [ "$status" -eq 0 ]
    grep -qx 'doctor' "$CALLS"
}

@test "maintenance commands are routed to the repo script" {
    ROOT_SCRIPT="$BATS_TEST_TMPDIR/maintenance.sh"
    cat >"$ROOT_SCRIPT" <<'EOF'
#!/usr/bin/env bash
printf '%s
' "maintenance $*" >>"$CALLS"
EOF
    chmod +x "$ROOT_SCRIPT"
    # bin/gothic resolves maintenance next to its own repository; point the
    # test at a copy of the CLI inside a throwaway tree with the stub.
    mkdir -p "$BATS_TEST_TMPDIR/repo/bin" "$BATS_TEST_TMPDIR/repo/scripts"
    cp "$GOTHIC" "$BATS_TEST_TMPDIR/repo/bin/gothic"
    cp "$ROOT_SCRIPT" "$BATS_TEST_TMPDIR/repo/scripts/maintenance.sh"

    run "$BATS_TEST_TMPDIR/repo/bin/gothic" snapshot work
    [ "$status" -eq 0 ]
    grep -qx 'maintenance snapshot work' "$CALLS"

    run "$BATS_TEST_TMPDIR/repo/bin/gothic" update --dry-run
    [ "$status" -eq 0 ]
    grep -qx 'maintenance update --dry-run' "$CALLS"
}

@test "help exits zero and prints the command surface" {
    run "$GOTHIC" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"gothic status"* ]]
    [[ "$output" == *"gothic session"* ]]
}

@test "version names the tool and the revision" {
    run "$GOTHIC" version
    [ "$status" -eq 0 ]
    [[ "$output" == "gothic (gothic-dots) "* ]]
}

@test "an unknown command prints usage and exits non-zero" {
    run "$GOTHIC" bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
