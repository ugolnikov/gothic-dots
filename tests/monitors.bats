#!/usr/bin/env bats
# Tests for config/hypr/scripts/monitors.sh — saved arrangements keyed by EDID
# description, applied through hyprctl keyword. hyprctl serves a JSON fixture
# and records the keyword calls; no real outputs are touched.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    MODULE="$REPO_ROOT/config/hypr/scripts/monitors.sh"
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    export MONITORS_DIR="$XDG_CONFIG_HOME/hypr/monitors"
    export MONITORS_AUTO="$XDG_CONFIG_HOME/hypr/monitors-auto"
    export MONITORS_DELAY=0
    mkdir -p "$HOME" "$XDG_CONFIG_HOME/hypr"

    CALLS="$BATS_TEST_TMPDIR/calls.log"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    MONITORS_JSON="$BATS_TEST_TMPDIR/monitors.json"
    mkdir -p "$STUB_BIN"
    export CALLS STUB_BIN MONITORS_JSON
    export PATH="$STUB_BIN:$PATH"

    cat >"$MONITORS_JSON" <<'EOF'
[
 {"name":"DP-1","description":"Dell U2720Q","width":3840,"height":2160,"refreshRate":60,"x":0,"y":0,"scale":1.5,"transform":0,"mirrorOf":"none","disabled":false},
 {"name":"HDMI-A-1","description":"LG TV","width":1920,"height":1080,"refreshRate":60,"x":3840,"y":0,"scale":1,"transform":0,"mirrorOf":"none","disabled":false}
]
EOF

    cat >"$STUB_BIN/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    "monitors -j") cat "$MONITORS_JSON" ;;
    keyword\ *) printf 'hyprctl %s\n' "$*" >>"$CALLS" ;;
esac
EOF
    cat >"$STUB_BIN/rofi" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' "${ROFI_CHOICE:-}"
EOF
    cat >"$STUB_BIN/notify-send" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$STUB_BIN"/*
}

@test "save writes the current arrangement with EDID and geometry" {
    run "$MODULE" save work
    [ "$status" -eq 0 ]
    [ -r "$MONITORS_DIR/work.tsv" ]
    grep -q $'DP-1\tDell U2720Q\t3840x2160@60\t0x0\t1.5\t0\t-\t0' "$MONITORS_DIR/work.tsv"
    grep -q $'HDMI-A-1\tLG TV\t1920x1080@60\t3840x0\t1\t0\t-\t0' "$MONITORS_DIR/work.tsv"
}

@test "apply finds outputs by description after the port names change" {
    "$MODULE" save work
    sed -i 's/"name":"DP-1"/"name":"DP-9"/; s/"name":"HDMI-A-1"/"name":"HDMI-9"/' "$MONITORS_JSON"

    run "$MODULE" apply work
    [ "$status" -eq 0 ]
    grep -qx 'hyprctl keyword monitor DP-9,3840x2160@60,0x0,1.5,transform,0' "$CALLS"
    grep -qx 'hyprctl keyword monitor HDMI-9,1920x1080@60,3840x0,1,transform,0' "$CALLS"
}

@test "apply falls back to the output name when the description differs" {
    "$MODULE" save work
    sed -i 's/"description":"Dell U2720Q"/"description":"Other Panel"/' "$MONITORS_JSON"

    run "$MODULE" apply work
    [ "$status" -eq 0 ]
    grep -qx 'hyprctl keyword monitor DP-1,3840x2160@60,0x0,1.5,transform,0' "$CALLS"
}

@test "a disabled output is switched off last" {
    mkdir -p "$MONITORS_DIR"
    cat >"$MONITORS_DIR/tv.tsv" <<'EOF'
# name	description	mode	position	scale	transform	mirror	disabled
HDMI-A-1	LG TV	1920x1080@60	3840x0	1	0	-	1
EOF

    run "$MODULE" apply tv
    [ "$status" -eq 0 ]
    grep -qx 'hyprctl keyword monitor HDMI-A-1,disable' "$CALLS"
    ! grep -q '1920x1080' "$CALLS"
}

@test "a mirror references the current name of the saved target" {
    mkdir -p "$MONITORS_DIR"
    cat >"$MONITORS_DIR/mirror.tsv" <<'EOF'
# name	description	mode	position	scale	transform	mirror	disabled
DP-1	Dell U2720Q	3840x2160@60	0x0	1.5	0	HDMI-A-1	0
HDMI-A-1	LG TV	1920x1080@60	3840x0	1	0	-	0
EOF

    run "$MODULE" apply mirror
    [ "$status" -eq 0 ]
    grep -qx 'hyprctl keyword monitor DP-1,3840x2160@60,0x0,1.5,transform,0,mirror,HDMI-A-1' "$CALLS"
}

@test "auto remembers a profile and autoload applies it" {
    "$MODULE" save work

    run "$MODULE" auto work
    [ "$status" -eq 0 ]
    [ "$(cat "$MONITORS_AUTO")" = work ]

    run "$MODULE" autoload
    [ "$status" -eq 0 ]
    grep -q '^hyprctl keyword monitor DP-1' "$CALLS"

    run "$MODULE" auto off
    [ "$status" -eq 0 ]
    [ ! -e "$MONITORS_AUTO" ]
}

@test "autoload is a no-op without the marker" {
    run "$MODULE" autoload
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "list, show, delete and status work on the store" {
    "$MODULE" save work

    run "$MODULE" list
    [ "$status" -eq 0 ]
    [ "$output" = work ]

    run "$MODULE" show work
    [ "$status" -eq 0 ]
    [[ "$output" == *"Dell U2720Q"* ]]

    run "$MODULE" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"сохранено: 1"* ]]
    [[ "$output" == *"автоприменение: выключено"* ]]

    run "$MODULE" delete work
    [ "$status" -eq 0 ]
    [ ! -e "$MONITORS_DIR/work.tsv" ]
}

@test "deleting the auto profile also clears the marker" {
    "$MODULE" save work
    "$MODULE" auto work

    run "$MODULE" delete work
    [ "$status" -eq 0 ]
    [ ! -e "$MONITORS_AUTO" ]
}

@test "current prints the connected outputs" {
    run "$MODULE" current
    [ "$status" -eq 0 ]
    [[ "$output" == *"DP-1"* ]]
    [[ "$output" == *"3840x2160"* ]]
}

@test "the menu applies the chosen profile" {
    "$MODULE" save work
    export ROFI_CHOICE=work

    run "$MODULE" menu
    [ "$status" -eq 0 ]
    grep -q '^hyprctl keyword monitor DP-1' "$CALLS"
}

@test "applying a missing profile fails loudly" {
    run "$MODULE" apply nope
    [ "$status" -eq 1 ]
    [[ "$output" == *"нет раскладки"* ]]
}

@test "a profile name with a path separator is rejected" {
    run "$MODULE" save ../escape
    [ "$status" -eq 1 ]
    [[ "$output" == *"недопустимое имя"* ]]
}

@test "an unknown action prints usage" {
    run "$MODULE" bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
