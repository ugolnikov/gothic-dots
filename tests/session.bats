#!/usr/bin/env bats
# Tests for config/hypr/scripts/session.sh — saving and restoring the window
# layout. Run with:
#
#   bats tests/
#
# The compositor is stubbed: hyprctl prints the fixture in $CLIENTS_FILE and
# records dispatches, /proc is a throwaway tree (SESSION_PROC) holding fake
# cmdline/cwd entries, and setsid logs instead of launching. So the layout logic
# is exercised end to end without Hyprland and nothing real is started.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SESSION="$REPO_ROOT/config/hypr/scripts/session.sh"
    CONFIG="$BATS_TEST_TMPDIR/config"
    STATE_DIR="$CONFIG/hypr"

    export XDG_CONFIG_HOME="$CONFIG"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$STATE_DIR" "$HOME"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUB_BIN"
    export STUB_BIN CALLS
    export PATH="$STUB_BIN:$PATH"

    # Fake /proc for the saved command lines and working directories.
    export SESSION_PROC="$BATS_TEST_TMPDIR/proc"
    mkdir -p "$SESSION_PROC/4242" "$SESSION_PROC/5252"
    printf 'foot\0--server\0' >"$SESSION_PROC/4242/cmdline"
    printf 'firefox\0--new-window\0' >"$SESSION_PROC/5252/cmdline"
    ln -s "$HOME" "$SESSION_PROC/4242/cwd"
    ln -s "$HOME" "$SESSION_PROC/5252/cwd"

    # Short waits so a restore that launches never stalls the suite.
    export SESSION_WAIT=3
    export SESSION_POLL=0.05

    export CLIENTS_FILE="$BATS_TEST_TMPDIR/clients.json"
    export CLIENTS_AFTER=""

    cat >"$STUB_BIN/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    clients) cat "$CLIENTS_FILE" ;;
    activewindow) printf '{"address":"%s"}\n' "${ACTIVE_ADDR:-0xprev}" ;;
    dispatch)
        printf '%s\n' "dispatch ${*:2}" >>"$CALLS"
        ;;
    *) exit 0 ;;
esac
EOF
    # setsid stands in for "the application started": a test can hand it the
    # client list that appears after the launch.
    cat >"$STUB_BIN/setsid" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "setsid $*" >>"$CALLS"
if [ -n "${CLIENTS_AFTER:-}" ]; then
    cp "$CLIENTS_AFTER" "$CLIENTS_FILE"
fi
EOF
    cat >"$STUB_BIN/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "notify-send $*" >>"$CALLS"
EOF
    cat >"$STUB_BIN/rofi" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
n="$(cat "$ROFI_COUNT" 2>/dev/null || echo 0)"
n=$((n + 1))
printf '%s\n' "$n" >"$ROFI_COUNT"
sed -n "${n}p" "$ROFI_QUEUE"
EOF
    chmod +x "$STUB_BIN/hyprctl" "$STUB_BIN/setsid" "$STUB_BIN/notify-send" "$STUB_BIN/rofi"

    # A current layout: foot tiled on workspace 2, firefox floating on 3.
    cat >"$CLIENTS_FILE" <<'EOF'
[
  {"address":"0xaaa","mapped":true,"class":"foot","title":"foot","workspace":{"id":2,"name":"2"},
   "floating":false,"pinned":false,"fullscreen":0,"at":[0,0],"size":[800,600],"pid":4242},
  {"address":"0xbbb","mapped":true,"class":"firefox","title":"Docs","workspace":{"id":3,"name":"3"},
   "floating":true,"pinned":false,"fullscreen":0,"at":[100,50],"size":[900,700],"pid":5252}
]
EOF

    # What the client list looks like after the missing firefox is launched.
    cat >"$BATS_TEST_TMPDIR/after.json" <<'EOF'
[
  {"address":"0xaaa","mapped":true,"class":"foot","title":"foot","workspace":{"id":1,"name":"1"},
   "floating":false,"pinned":false,"fullscreen":0,"at":[0,0],"size":[800,600],"pid":4242},
  {"address":"0xbbb","mapped":true,"class":"firefox","title":"Docs","workspace":{"id":1,"name":"1"},
   "floating":true,"pinned":false,"fullscreen":0,"at":[0,0],"size":[600,400],"pid":5252}
]
EOF
}

@test "save writes a session with workspace, argv and cwd" {
    run "$SESSION" save work
    [ "$status" -eq 0 ]
    [ -f "$STATE_DIR/sessions/work.json" ]
    [ "$(stat -c %a "$STATE_DIR/sessions/work.json")" = 600 ]

    run jq -r '.clients[0].ws' "$STATE_DIR/sessions/work.json"
    [ "$output" = 2 ]
    run jq -r '.clients[0].cmd | join(" ")' "$STATE_DIR/sessions/work.json"
    [ "$output" = "foot --server" ]
    run jq -r '.clients[0].cwd' "$STATE_DIR/sessions/work.json"
    [ "$output" = "$HOME" ]
    run jq -r '.clients[1].floating' "$STATE_DIR/sessions/work.json"
    [ "$output" = true ]
}

@test "save keeps a copy under last so restore last works" {
    "$SESSION" save work
    [ -f "$STATE_DIR/sessions/last.json" ]
    [ "$(jq -r '.name' "$STATE_DIR/sessions/last.json")" = work ]
}

@test "save rejects a name that is not a plain file name" {
    run "$SESSION" save "bad name"
    [ "$status" -eq 2 ]
    [[ "$output" == *"имя сессии"* ]]
    [ ! -d "$STATE_DIR/sessions" ]
}

@test "list, show and delete report the saved session" {
    "$SESSION" save work

    run "$SESSION" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"work"* ]]
    [[ "$output" != *"last"* ]]

    run "$SESSION" count
    [ "$status" -eq 0 ]
    [ "$output" = 1 ]

    run "$SESSION" show work
    [ "$status" -eq 0 ]
    [[ "$output" == *"окон 2"* ]]
    [[ "$output" == *"firefox"* ]]
    [[ "$output" == *"foot --server"* ]]

    run "$SESSION" delete work
    [ "$status" -eq 0 ]
    [ ! -f "$STATE_DIR/sessions/work.json" ]
}

@test "restore moves matching windows back to their workspaces" {
    "$SESSION" save work
    cat >"$CLIENTS_FILE" <<'EOF'
[
  {"address":"0xaaa","mapped":true,"class":"foot","title":"foot","workspace":{"id":1,"name":"1"},
   "floating":false,"pinned":false,"fullscreen":0,"at":[0,0],"size":[800,600],"pid":4242},
  {"address":"0xbbb","mapped":true,"class":"firefox","title":"Docs","workspace":{"id":1,"name":"1"},
   "floating":true,"pinned":false,"fullscreen":0,"at":[0,0],"size":[600,400],"pid":5252}
]
EOF

    run "$SESSION" restore work
    [ "$status" -eq 0 ]
    grep -qx 'dispatch movetoworkspacesilent 2,address:0xaaa' "$CALLS"
    grep -qx 'dispatch movetoworkspacesilent 3,address:0xbbb' "$CALLS"
    grep -qx 'dispatch movewindowpixel exact 100 50,address:0xbbb' "$CALLS"
    grep -qx 'dispatch resizewindowpixel exact 900 700,address:0xbbb' "$CALLS"
    [[ "$output" == *"окон 2"* ]]
    [[ "$output" == *"запущено 0"* ]]
}

@test "restore launches the missing application with its saved argv" {
    "$SESSION" save work
    # Only the terminal is open; firefox has to be launched and then placed.
    cat >"$CLIENTS_FILE" <<'EOF'
[
  {"address":"0xaaa","mapped":true,"class":"foot","title":"foot","workspace":{"id":1,"name":"1"},
   "floating":false,"pinned":false,"fullscreen":0,"at":[0,0],"size":[800,600],"pid":4242}
]
EOF
    export CLIENTS_AFTER="$BATS_TEST_TMPDIR/after.json"

    run "$SESSION" restore work
    [ "$status" -eq 0 ]
    grep -qx 'setsid firefox --new-window' "$CALLS"
    grep -qx 'dispatch movetoworkspacesilent 3,address:0xbbb' "$CALLS"
    [[ "$output" == *"запущено 1"* ]]
}

@test "restore launches one process per distinct command" {
    cat >"$CLIENTS_FILE" <<'EOF'
[
  {"address":"0xaaa","mapped":true,"class":"foot","title":"one","workspace":{"id":2,"name":"2"},
   "floating":false,"pinned":false,"fullscreen":0,"at":[0,0],"size":[800,600],"pid":4242},
  {"address":"0xaab","mapped":true,"class":"foot","title":"two","workspace":{"id":5,"name":"5"},
   "floating":false,"pinned":false,"fullscreen":0,"at":[0,0],"size":[800,600],"pid":4242}
]
EOF
    "$SESSION" save two-terms

    cat >"$CLIENTS_FILE" <<'EOF'
[]
EOF
    run "$SESSION" restore two-terms
    [ "$status" -eq 0 ]
    [ "$(grep -c '^setsid ' "$CALLS")" -eq 1 ]
    [[ "$output" == *"запущено 1"* ]]
}

@test "restore gives every same-class window a distinct address" {
    cat >"$CLIENTS_FILE" <<'EOF'
[
  {"address":"0xaaa","mapped":true,"class":"foot","title":"one","workspace":{"id":2,"name":"2"},
   "floating":false,"pinned":false,"fullscreen":0,"at":[0,0],"size":[800,600],"pid":4242},
  {"address":"0xaab","mapped":true,"class":"foot","title":"two","workspace":{"id":5,"name":"5"},
   "floating":false,"pinned":false,"fullscreen":0,"at":[0,0],"size":[800,600],"pid":4242}
]
EOF
    "$SESSION" save two-terms

    cat >"$CLIENTS_FILE" <<'EOF'
[
  {"address":"0xaab","mapped":true,"class":"foot","title":"two","workspace":{"id":1,"name":"1"},
   "floating":false,"pinned":false,"fullscreen":0,"at":[0,0],"size":[800,600],"pid":4242},
  {"address":"0xaaa","mapped":true,"class":"foot","title":"one","workspace":{"id":1,"name":"1"},
   "floating":false,"pinned":false,"fullscreen":0,"at":[0,0],"size":[800,600],"pid":4242}
]
EOF
    run "$SESSION" restore two-terms
    [ "$status" -eq 0 ]
    grep -qx 'dispatch movetoworkspacesilent 5,address:0xaab' "$CALLS"
    grep -qx 'dispatch movetoworkspacesilent 2,address:0xaaa' "$CALLS"
}

@test "restore keeps a named special workspace name" {
    cat >"$CLIENTS_FILE" <<'EOF'
[
  {"address":"0xccc","mapped":true,"class":"btop","title":"btop","workspace":{"id":-99,"name":"special:magic"},
   "floating":true,"pinned":false,"fullscreen":0,"at":[10,10],"size":[500,400],"pid":4242}
]
EOF
    "$SESSION" save scratch

    cat >"$CLIENTS_FILE" <<'EOF'
[
  {"address":"0xccc","mapped":true,"class":"btop","title":"btop","workspace":{"id":1,"name":"1"},
   "floating":true,"pinned":false,"fullscreen":0,"at":[0,0],"size":[100,100],"pid":4242}
]
EOF
    run "$SESSION" restore scratch
    [ "$status" -eq 0 ]
    grep -qx 'dispatch movetoworkspacesilent special:magic,address:0xccc' "$CALLS"
}

@test "restore restores fullscreen through a focus round trip" {
    cat >"$CLIENTS_FILE" <<'EOF'
[
  {"address":"0xaaa","mapped":true,"class":"foot","title":"foot","workspace":{"id":2,"name":"2"},
   "floating":false,"pinned":false,"fullscreen":2,"at":[0,0],"size":[1920,1080],"pid":4242}
]
EOF
    "$SESSION" save full

    cat >"$CLIENTS_FILE" <<'EOF'
[
  {"address":"0xaaa","mapped":true,"class":"foot","title":"foot","workspace":{"id":1,"name":"1"},
   "floating":false,"pinned":false,"fullscreen":0,"at":[0,0],"size":[800,600],"pid":4242}
]
EOF
    run "$SESSION" restore full
    [ "$status" -eq 0 ]
    grep -qx 'dispatch focuswindow address:0xaaa' "$CALLS"
    grep -qx 'dispatch fullscreenstate 2 -1' "$CALLS"
    grep -qx 'dispatch focuswindow address:0xprev' "$CALLS"
}

@test "dry run prints the plan and changes nothing" {
    "$SESSION" save work
    cat >"$CLIENTS_FILE" <<'EOF'
[]
EOF

    run "$SESSION" restore work --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"запуск:"* ]]
    [[ "$output" == *"ничего не изменено"* ]]
    ! grep -q '^dispatch' "$CALLS"
    ! grep -q '^setsid' "$CALLS"
}

@test "restore reports windows it cannot place" {
    "$SESSION" save work
    cat >"$CLIENTS_FILE" <<'EOF'
[]
EOF
    # No command line for the firefox entry: it can neither be matched nor launched.
    jq '.clients[1].cmd = []' "$STATE_DIR/sessions/work.json" >"$BATS_TEST_TMPDIR/tmp.json"
    mv "$BATS_TEST_TMPDIR/tmp.json" "$STATE_DIR/sessions/work.json"

    run "$SESSION" restore work
    [ "$status" -eq 0 ]
    [[ "$output" == *"не найдено 2"* ]]
}

@test "restore refuses a name with no snapshot" {
    run "$SESSION" restore ghost
    [ "$status" -eq 2 ]
    [[ "$output" == *"нет снимка"* ]]
}

@test "the menu restores the picked snapshot" {
    "$SESSION" save work
    cat >"$CLIENTS_FILE" <<'EOF'
[
  {"address":"0xaaa","mapped":true,"class":"foot","title":"foot","workspace":{"id":1,"name":"1"},
   "floating":false,"pinned":false,"fullscreen":0,"at":[0,0],"size":[800,600],"pid":4242},
  {"address":"0xbbb","mapped":true,"class":"firefox","title":"Docs","workspace":{"id":1,"name":"1"},
   "floating":true,"pinned":false,"fullscreen":0,"at":[0,0],"size":[600,400],"pid":5252}
]
EOF
    export ROFI_QUEUE="$BATS_TEST_TMPDIR/rofi.queue"
    export ROFI_COUNT="$BATS_TEST_TMPDIR/rofi.count"
    printf '%s\n%s\n' "Восстановить сессию" "work" >"$ROFI_QUEUE"

    run "$SESSION" menu
    [ "$status" -eq 0 ]
    grep -qx 'dispatch movetoworkspacesilent 2,address:0xaaa' "$CALLS"
}
