#!/usr/bin/env bats
# Tests for config/hypr/scripts/launcher.sh (SUPER + D, SUPER + Space). Run with:
#
#   bats tests/
#
# The default mode prefers tofi-drun and falls back to rofi; the extra modes
# (files, windows, clipboard, ssh, packages, calc, hub) are pure row providers
# plus a dmenu choice, so they can be driven with stubs and a throwaway HOME.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    LAUNCHER="$REPO_ROOT/config/hypr/scripts/launcher.sh"

    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_CACHE_HOME="$HOME/.cache"
    mkdir -p "$XDG_CACHE_HOME" "$HOME/.ssh"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUB_BIN"
    export STUB_BIN CALLS
    export PATH="$STUB_BIN:$PATH"

    cat >"$STUB_BIN/tofi-drun" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "tofi-drun${*:+ $*}" >>"$CALLS"
EOF

    # rofi logs every call; in dmenu mode it consumes stdin and, when
    # ROFI_CHOICE is set, returns the matching row so a mode can be driven.
    cat >"$STUB_BIN/rofi" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "rofi $*" >>"$CALLS"
case " $* " in
    *" -dmenu "*)
        input="$(cat)"
        if [ -n "${ROFI_CHOICE:-}" ]; then
            # A real dmenu accepts typed text that matches no row; the stub
            # returns the matching row, else the typed query itself.
            printf '%s\n' "$input" | grep -m1 -F -- "$ROFI_CHOICE" ||
                printf '%s\n' "$ROFI_CHOICE"
        fi
        ;;
esac
EOF

    cat >"$STUB_BIN/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    clients) cat "$CLIENTS_FILE" ;;
    dispatch) printf '%s\n' "hyprctl dispatch ${*:2}" >>"$CALLS" ;;
esac
EOF

    cat >"$STUB_BIN/fd" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$HOME/notes.txt" "$HOME/pictures/cat.png"
EOF

    cat >"$STUB_BIN/cliphist" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    list) printf '1\tfoo\n2\tbar baz\n' ;;
    decode) cut -f2- ;;
esac
EOF

    cat >"$STUB_BIN/wl-copy" <<'EOF'
#!/usr/bin/env bash
body="$(cat)"
printf '%s\n' "wl-copy $body" >>"$CALLS"
EOF

    cat >"$STUB_BIN/pacman" <<'EOF'
#!/usr/bin/env bash
printf 'extra/foo 1.0-1\n    Foo thing\nextra/bar 2.0-1\n    Bar thing\n'
EOF

    for tool in xdg-open setsid notify-send gothic; do
        cat >"$STUB_BIN/$tool" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "$tool \$*" >>"\$CALLS"
EOF
    done
    chmod +x "$STUB_BIN"/*

    export CLIENTS_FILE="$BATS_TEST_TMPDIR/clients.json"
    cat >"$CLIENTS_FILE" <<'EOF'
[
  {"address":"0xabc","mapped":true,"class":"foot","title":"term","workspace":{"id":2,"name":"2"}},
  {"address":"0xdef","mapped":true,"class":"firefox","title":"Docs","workspace":{"id":3,"name":"3"}}
]
EOF
}

@test "tofi-drun is used when available" {
    run "$LAUNCHER"
    [ "$status" -eq 0 ]
    grep -qx 'tofi-drun' "$CALLS"
    ! grep -q '^rofi' "$CALLS"
}

@test "tofi-drun gets the wallust config with -c when it exists" {
    mkdir -p "$XDG_CACHE_HOME/wallust"
    : >"$XDG_CACHE_HOME/wallust/tofi"

    run "$LAUNCHER"
    [ "$status" -eq 0 ]
    grep -qx "tofi-drun -c $XDG_CACHE_HOME/wallust/tofi" "$CALLS"
}

@test "tofi-drun starts without -c when the wallust config is absent" {
    run "$LAUNCHER"
    [ "$status" -eq 0 ]
    grep -qx 'tofi-drun' "$CALLS"
}

@test "rofi is the fallback when tofi-drun is absent" {
    rm -f "$STUB_BIN/tofi-drun"

    run "$LAUNCHER"
    [ "$status" -eq 0 ]
    grep -qx 'rofi -show drun' "$CALLS"
}

# The fallback must not read the tofi config: rofi has its own theme.
@test "rofi is used even when the tofi config exists" {
    rm -f "$STUB_BIN/tofi-drun"
    mkdir -p "$XDG_CACHE_HOME/wallust"
    : >"$XDG_CACHE_HOME/wallust/tofi"

    run "$LAUNCHER"
    [ "$status" -eq 0 ]
    grep -qx 'rofi -show drun' "$CALLS"
}

# --- modes ----------------------------------------------------------------

@test "windows mode lists workspace, class and title" {
    run "$LAUNCHER" windows --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"2  foot  term"* ]]
    [[ "$output" == *"3  firefox  Docs"* ]]
}

@test "picking a window focuses its address" {
    export ROFI_CHOICE="2  foot  term"

    run "$LAUNCHER" windows
    [ "$status" -eq 0 ]
    grep -qx 'hyprctl dispatch focuswindow address:0xabc' "$CALLS"
}

@test "files mode lists matches and opens the pick" {
    run "$LAUNCHER" files --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"$HOME/notes.txt"* ]]

    export ROFI_CHOICE="$HOME/notes.txt"
    run "$LAUNCHER" files
    [ "$status" -eq 0 ]
    sleep 0.2
    grep -qx "setsid xdg-open $HOME/notes.txt" "$CALLS"
}

@test "clipboard mode lists history and copies the decoded pick" {
    run "$LAUNCHER" clipboard --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"1  foo"* ]]

    export ROFI_CHOICE="1  foo"
    run "$LAUNCHER" clipboard
    [ "$status" -eq 0 ]
    grep -qx 'wl-copy foo' "$CALLS"
}

@test "ssh mode parses Host entries and skips wildcards" {
    cat >"$HOME/.ssh/config" <<'EOF'
Host alpha
    HostName alpha.example

Host *.internal
    User nobody

Host beta
EOF

    run "$LAUNCHER" ssh --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]]
    [[ "$output" == *"beta"* ]]
    [[ "$output" != *"*.internal"* ]]
}

@test "packages mode lists names from the package manager" {
    run "$LAUNCHER" packages --list foo
    [ "$status" -eq 0 ]
    [[ "$output" == *"foo"* ]]
    [[ "$output" == *"bar"* ]]
}

@test "calc evaluates an expression" {
    run "$LAUNCHER" calc "2+2*3"
    [ "$status" -eq 0 ]
    [[ "$output" == 8* ]]
}

@test "calc rejects anything that is not arithmetic" {
    run "$LAUNCHER" calc 'system("id")'
    [ "$status" -eq 2 ]
    [[ "$output" == *"только цифры"* ]]
}

@test "the hub delegates a picked command to gothic" {
    export ROFI_CHOICE="Тема: готика"

    run "$LAUNCHER" menu
    [ "$status" -eq 0 ]
    grep -qx 'gothic theme dark' "$CALLS"
}

@test "the hub accepts a typed :verb and passes it to gothic" {
    export ROFI_CHOICE=":theme light"

    run "$LAUNCHER" menu
    [ "$status" -eq 0 ]
    grep -qx 'gothic theme light' "$CALLS"
}

@test "an unknown launcher mode prints usage" {
    run "$LAUNCHER" bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
