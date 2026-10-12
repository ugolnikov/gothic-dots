#!/usr/bin/env bats
# Smoke and regression tests for the dotfiles tooling. Run with:
#
#   bats tests/
#
# They exercise the guard scripts and install.sh against the real repository,
# so a broken invariant (a bind with no docs, an unlinked config, a stale
# keybind table) fails here before it reaches CI.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    cd "$REPO_ROOT"
}

@test "install.sh --dry-run succeeds and changes nothing" {
    run ./install.sh --no-packages --dry-run
    [ "$status" -eq 0 ]
}

# Regression: install.sh once looked for .tmux.conf/.gitconfig while the repo
# keeps them un-dotted, so a fresh install silently skipped both.
@test "install.sh links gitconfig and tmux.conf to their dotfile targets" {
    run ./install.sh --no-packages --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"dotfiles/gitconfig $HOME/.gitconfig"* ]]
    [[ "$output" == *"dotfiles/tmux.conf $HOME/.tmux.conf"* ]]
}

@test "check-coverage: every tracked config is installed by install.sh" {
    run ./scripts/check-coverage.sh
    [ "$status" -eq 0 ]
}

@test "check-binds: binds have documented keys, real scripts and known dispatchers" {
    run ./scripts/check-binds.sh
    [ "$status" -eq 0 ]
}

@test "gen-keybinds --check: README keybind table is in sync" {
    run ./scripts/gen-keybinds.sh --check
    [ "$status" -eq 0 ]
}

@test "scan-secrets --all: the repository is clean" {
    run ./scripts/scan-secrets.sh --all
    [ "$status" -eq 0 ]
}

@test "theme-mode.sh status reports light or dark" {
    run ./config/hypr/scripts/theme-mode.sh status
    [ "$status" -eq 0 ]
    [[ "$output" == "light" || "$output" == "dark" ]]
}

@test "install.sh --only links just the named app" {
    run ./install.sh --no-packages --only hypr --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"/config/hypr /"* ]]
    [[ "$output" != *"/config/waybar"* ]]
    [[ "$output" != *"/dotfiles/fish"* ]]
}

# Exercise the real script against a throwaway clone + local bare remote, so it
# can't touch the actual origin: the snapshot must land on its own branch and
# leave `main` (and the working tree) alone.
@test "dotfiles-backup snapshots to a branch without moving main" {
    command -v git >/dev/null || skip "git not available"
    git -C "$REPO_ROOT" config user.email >/dev/null 2>&1 || skip "no git identity"

    remote="$BATS_TEST_TMPDIR/remote.git"
    work="$BATS_TEST_TMPDIR/work"
    git init -q --bare "$remote"
    git clone -q "$REPO_ROOT" "$work"
    git -C "$work" remote set-url origin "$remote"
    git -C "$work" push -q origin HEAD:refs/heads/main
    main_before="$(git -C "$work" rev-parse origin/main)"

    echo "# bats snapshot" >>"$work/README.md"
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    run "$work/scripts/dotfiles-backup.sh"
    [ "$status" -eq 0 ]

    run git -C "$work" ls-remote --heads origin
    [[ "$output" == *"refs/heads/snapshots"* ]]
    [ "$(git -C "$work" rev-parse origin/main)" = "$main_before" ]
    run git -C "$work" status --porcelain
    [[ "$output" == *"README.md"* ]]
}
