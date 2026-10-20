#!/usr/bin/env bats
# Tests for config/hypr/scripts/keyboard-memory.sh — per-class xkb memory.
# hyprctl is a stub that serves an active window and a keyboard layout list;
# jq is the real one, and the state file lives in a throwaway config tree.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    MODULE="$REPO_ROOT/config/hypr/scripts/keyboard-memory.sh"
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    STATE="$XDG_CONFIG_HOME/hypr"
    export KEYBOARD_MEMORY_FILE="$STATE/keyboard-memory.tsv"
    mkdir -p "$STATE" "$HOME"

    CALLS="$BATS_TEST_TMPDIR/calls.log"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"
    export CALLS STUB_BIN
    export PATH="$STUB_BIN:$PATH"

    cat >"$STUB_BIN/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    "activewindow -j")
        printf '{"class":"%s"}\n' "${ACTIVE_CLASS-foot}"
        ;;
    "devices -j")
        cat <<'JSON'
{"keyboards":[
  {"name":"kbd","main":true,"layouts":["English (US)","Russian"]},
  {"name":"extra","main":false,"layouts":["English (US)"]}
]}
JSON
        ;;
    switchxkblayout\ *)
        printf 'hyprctl %s\n' "$*" >>"$CALLS"
        ;;
esac
EOF
    chmod +x "$STUB_BIN/hyprctl"
}

@test "remember-active stores the active class and layout" {
    run "$MODULE" remember-active "Russian"
    [ "$status" -eq 0 ]
    grep -qx $'foot\tRussian' "$KEYBOARD_MEMORY_FILE"
}

@test "restore switches to the remembered layout index" {
    printf 'foot\tRussian\n' >"$KEYBOARD_MEMORY_FILE"

    run "$MODULE" restore foot
    [ "$status" -eq 0 ]
    grep -qx 'hyprctl switchxkblayout kbd 1' "$CALLS"
}

@test "restore leaves an unknown class alone" {
    printf 'foot\tRussian\n' >"$KEYBOARD_MEMORY_FILE"

    run "$MODULE" restore firefox
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "re-remembering a class replaces its line and keeps the others" {
    printf 'firefox\tEnglish (US)\nfoot\tEnglish (US)\n' >"$KEYBOARD_MEMORY_FILE"

    run "$MODULE" remember-active "Russian"
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$KEYBOARD_MEMORY_FILE")" -eq 2 ]
    grep -qx $'firefox\tEnglish (US)' "$KEYBOARD_MEMORY_FILE"
    grep -qx $'foot\tRussian' "$KEYBOARD_MEMORY_FILE"
}

@test "list prints the table and status counts it" {
    printf 'foot\tRussian\nfirefox\tEnglish (US)\n' >"$KEYBOARD_MEMORY_FILE"

    run "$MODULE" list
    [ "$status" -eq 0 ]
    [[ "$output" == *$'foot\tRussian'* ]]

    run "$MODULE" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"записей: 2"* ]]
    [[ "$output" == *"активное окно: foot"* ]]
}

@test "clear removes the memory" {
    printf 'foot\tRussian\n' >"$KEYBOARD_MEMORY_FILE"

    run "$MODULE" clear
    [ "$status" -eq 0 ]
    [ ! -e "$KEYBOARD_MEMORY_FILE" ]
}

@test "an empty active window is not remembered" {
    export ACTIVE_CLASS=""

    run "$MODULE" remember-active "Russian"
    [ "$status" -eq 0 ]
    [ ! -e "$KEYBOARD_MEMORY_FILE" ]
}

@test "a layout missing from the keyboard is ignored on restore" {
    printf 'foot\tKlingon\n' >"$KEYBOARD_MEMORY_FILE"

    run "$MODULE" restore foot
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "usage is rejected for an unknown action" {
    run "$MODULE" bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
