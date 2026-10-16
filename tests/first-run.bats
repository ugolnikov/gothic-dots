#!/usr/bin/env bats
# Tests for scripts/first-run.sh — the one-time setup wizard. It is driven at
# its command seam: --dry-run prints the exact command sequence and --yes runs
# it. The repo's own scripts and every external command it shells out to are
# stubbed on PATH, and HOME points at a throwaway tree, so no real
# pacman/chsh/sudo/make ever runs and the real home directory is never touched.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    export LOG="$BATS_TEST_TMPDIR/calls"
    STUB="$BATS_TEST_TMPDIR/stub"
    mkdir -p "$HOME" "$STUB"
    export PATH="$STUB:$PATH"
    : >"$LOG"

    # A shell list that carries fish, the rice's login shell.
    export SHELLS_FILE="$BATS_TEST_TMPDIR/shells"
    printf '%s\n' '# valid login shells' /bin/bash /usr/bin/fish >"$SHELLS_FILE"

    # Distro markers that claim Arch, so preflight stays quiet.
    export ARCH_RELEASE="$BATS_TEST_TMPDIR/arch-release"
    : >"$ARCH_RELEASE"
    export OS_RELEASE="$BATS_TEST_TMPDIR/os-release"
    printf 'ID=arch\n' >"$OS_RELEASE"

    stub make
    stub chsh
    stub pacman
    make_fake_repo
}

# stub <name> — a fake external command that records its call and succeeds.
stub() {
    cat >"$STUB/$1" <<EOF
#!/usr/bin/env bash
printf '%s%s\n' "$1" "\${*:+ \$*}" >>"$LOG"
exit 0
EOF
    chmod +x "$STUB/$1"
}

# log_stub <path> — a fake repo script that records its call and succeeds.
log_stub() {
    cat >"$1" <<EOF
#!/usr/bin/env bash
printf '%s%s\n' "\$(basename "\$0")" "\${*:+ \$*}" >>"$LOG"
exit 0
EOF
    chmod +x "$1"
}

# make_fake_repo — a throwaway checkout that carries the real wizard plus stubs
# for the scripts it drives, so ROOT resolves here and nothing real is invoked.
make_fake_repo() {
    REPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$REPO/scripts" "$REPO/config/hypr" "$REPO/fish" "$REPO/claude"
    ln -sfnT "$REPO_ROOT/scripts/first-run.sh" "$REPO/scripts/first-run.sh"
    log_stub "$REPO/install.sh"
    log_stub "$REPO/config/hypr/bootstrap.sh"
    log_stub "$REPO/scripts/doctor.sh"
}

# planned — the command sequence the wizard prints under --dry-run.
planned() {
    printf '%s\n' "$output" | sed -n 's/.*would run: //p'
}

@test "first-run.sh --dry-run prints the planned command sequence in order" {
    run "$REPO/scripts/first-run.sh" --dry-run
    [ "$status" -eq 0 ]

    planned >"$BATS_TEST_TMPDIR/plan"
    cat >"$BATS_TEST_TMPDIR/expected" <<EOF
$REPO/config/hypr/bootstrap.sh
$REPO/install.sh --no-packages
$REPO/install.sh --system
$REPO/install.sh --timer
chsh -s /usr/bin/fish
$REPO/scripts/doctor.sh
make -C $REPO test
EOF
    diff -u "$BATS_TEST_TMPDIR/expected" "$BATS_TEST_TMPDIR/plan"
}

@test "first-run.sh --dry-run changes nothing" {
    run "$REPO/scripts/first-run.sh" --dry-run
    [ "$status" -eq 0 ]

    [ ! -s "$LOG" ]
    [ ! -e "$HOME/.secrets.fish" ]
    # The throwaway HOME stays empty.
    [ -z "$(find "$HOME" -mindepth 1 -print -quit)" ]
}

@test "first-run.sh --dry-run points at the tracked secret examples" {
    run "$REPO/scripts/first-run.sh" --dry-run
    [ "$status" -eq 0 ]

    [[ "$output" == *"secrets.fish.EXAMPLE"* ]]
    [[ "$output" == *"settings.local.json.EXAMPLE"* ]]
}

@test "first-run.sh --yes runs each stage's command in order" {
    run "$REPO/scripts/first-run.sh" --yes
    [ "$status" -eq 0 ]

    cat >"$BATS_TEST_TMPDIR/expected" <<EOF
bootstrap.sh
install.sh --no-packages
install.sh --system
install.sh --timer
chsh -s /usr/bin/fish
doctor.sh
make -C $REPO test
EOF
    diff -u "$BATS_TEST_TMPDIR/expected" "$LOG"
}

@test "first-run.sh skips the package stage when pacman is absent" {
    rm -f "$STUB/pacman"

    run "$REPO/scripts/first-run.sh" --yes
    [ "$status" -eq 0 ]

    ! grep -q '^bootstrap.sh' "$LOG"
    [[ "$output" == *"still to do by hand"* ]]
    [[ "$output" == *"packages.txt"* ]]
}

@test "first-run.sh offers no shell change when fish is not installed" {
    printf '%s\n' '# valid login shells' /bin/bash /bin/zsh >"$SHELLS_FILE"

    run "$REPO/scripts/first-run.sh" --yes
    [ "$status" -eq 0 ]

    ! grep -q '^chsh' "$LOG"
    [[ "$output" == *"no login shell offered"* ]]
}

@test "first-run.sh declines every step when answered no" {
    run bash -c 'yes "" | "$1"' _ "$REPO/scripts/first-run.sh"
    [ "$status" -eq 0 ]

    [ ! -s "$LOG" ]
    [[ "$output" == *"still to do by hand"* ]]
}

@test "first-run.sh never creates the secret files" {
    run "$REPO/scripts/first-run.sh" --yes
    [ "$status" -eq 0 ]

    [ ! -e "$HOME/.secrets.fish" ]
    [ ! -e "$HOME/.claude/settings.local.json" ]
}

@test "first-run.sh rejects an unknown argument with usage on stderr" {
    run "$REPO/scripts/first-run.sh" --nope
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage: first-run.sh"* ]]
}
