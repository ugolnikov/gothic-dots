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
