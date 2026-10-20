#!/usr/bin/env bats
# Tests for bin/please — rerun the previous command through sudo. Run with:
#
#   bats tests/
#
# please reads the *parent shell's* history, so each test starts a real shell
# that reports itself as fish (a symlink to bash named "fish": `ps -o comm=`
# then says "fish") or as bash, and stubs sudo on PATH — nothing here may
# really escalate. Histories live in a throwaway HOME/XDG_DATA_HOME.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    PLEASE="$REPO_ROOT/bin/please"

    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_DATA_HOME="$BATS_TEST_TMPDIR/data"
    export SHELL="/bin/bash"
    FISH_HISTORY="$XDG_DATA_HOME/fish/fish_history"
    BASH_HISTORY="$BATS_TEST_TMPDIR/bash_history"
    SUDO_LOG="$BATS_TEST_TMPDIR/sudo.log"
    export SUDO_LOG HISTFILE="$BASH_HISTORY"
    mkdir -p "$HOME" "$XDG_DATA_HOME/fish"

    # sudo must never run for real: record the command it was asked to run,
    # minus the shell path it was handed (please calls `sudo "$SHELL" -c ...`).
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"
    cat >"$STUB_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${*:2}" >>"$SUDO_LOG"
EOF
    chmod +x "$STUB_BIN/sudo"

    ln -s "$(command -v bash)" "$STUB_BIN/fish"
    ln -s "$PLEASE" "$STUB_BIN/please"
    export PATH="$STUB_BIN:$PATH"
}

# run_please_from <shell> — run please from a parent whose comm is <shell>.
# Two details make this faithful: the chained command keeps bash from exec-ing
# please in place of itself (which would leave please's parent as bats), and
# `exit $?` forwards please's own exit status instead of the shell's.
run_please_from() {
    run "$1" -c 'please; exit $?'
}

@test "fish history: the list marker at column 0 is read" {
    printf '%s\n' '- cmd: echo first' '  when: 1' '- cmd: echo second' '  when: 2' >"$FISH_HISTORY"

    run_please_from fish
    [ "$status" -eq 0 ]

    run cat "$SUDO_LOG"
    [ "$output" = "-c echo second" ]
}

@test "fish history: an indented list marker is still read" {
    printf '%s\n' '  - cmd: echo legacy' '    when: 3' >"$FISH_HISTORY"

    run_please_from fish
    [ "$status" -eq 0 ]

    run cat "$SUDO_LOG"
    [ "$output" = "-c echo legacy" ]
}

@test "fish history: please and sudo lines are skipped" {
    printf '%s\n' '- cmd: echo keep' '- cmd: sudo pacman -Syu' '- cmd: please' >"$FISH_HISTORY"

    run_please_from fish
    [ "$status" -eq 0 ]

    run cat "$SUDO_LOG"
    [ "$output" = "-c echo keep" ]
}

@test "fish history: an unreadable history is reported" {
    rm -f "$FISH_HISTORY"

    run_please_from fish
    [ "$status" -eq 1 ]
    [[ "$output" == *"не удалось прочитать историю (fish)"* ]]
}

@test "bash history: the last entry is rerun" {
    printf '%s\n' 'echo one' '' 'echo two' >"$BASH_HISTORY"

    run_please_from bash
    [ "$status" -eq 0 ]

    run cat "$SUDO_LOG"
    [ "$output" = "-c echo two" ]
}

@test "bash history: nothing left to rerun exits quietly" {
    printf '%s\n' 'please' 'sudo ls' >"$BASH_HISTORY"

    run_please_from bash
    [ "$status" -eq 0 ]
    [ ! -s "$SUDO_LOG" ]
}
