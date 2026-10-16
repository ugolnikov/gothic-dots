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
    # Assert the source basename and destination, not the checkout directory
    # name: the suite must pass in a git worktree too, not only in ~/dotfiles.
    [[ "$output" == *"/gitconfig $HOME/.gitconfig"* ]]
    [[ "$output" == *"/tmux.conf $HOME/.tmux.conf"* ]]
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

@test "check-palette-targets: the module table agrees with the wallust config" {
    run ./scripts/check-palette-targets.sh
    [ "$status" -eq 0 ]
}

# Drift provocation: the guard must fail when a target is removed from one side
# but not the other. The input paths are overridable so the test provokes drift
# on copies and never edits the real table.
@test "check-palette-targets fails when the module table drops a target" {
    palette="$BATS_TEST_TMPDIR/palette.sh"
    grep -v 'swaync/colors.dynamic.css' config/hypr/scripts/palette.sh >"$palette"
    run env CHECK_PALETTE_SH="$palette" ./scripts/check-palette-targets.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"swaync/colors.dynamic.css"* ]]
}

@test "check-palette-targets fails when the generator drops a destination" {
    wallust="$BATS_TEST_TMPDIR/wallust.toml"
    grep -v 'swaync/colors.dynamic.css' config/wallust/wallust.toml >"$wallust"
    run env CHECK_WALLUST_TOML="$wallust" ./scripts/check-palette-targets.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"swaync/colors.dynamic.css"* ]]
}

@test "check-palette-targets fails when a target loses its ignore entry" {
    ignore="$BATS_TEST_TMPDIR/gitignore"
    grep -v '^config/kitty/colors.dynamic.conf$' .gitignore >"$ignore"
    run env CHECK_GITIGNORE="$ignore" ./scripts/check-palette-targets.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"kitty/colors.dynamic.conf"* ]]
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

# The entry point is a thin wrapper over the palette module: dark/light/toggle
# must drive the module's generated files and reload the same consumers. The
# module is driven through a throwaway config tree (XDG_CONFIG_HOME redirected)
# with the reload binaries stubbed on PATH, so the real ~/.config is untouched.
@test "theme-mode.sh drives the palette module's targets and reload" {
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    mkdir -p "$XDG_CONFIG_HOME"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_BIN"
    RELOAD_LOG="$BATS_TEST_TMPDIR/reload.log"
    export RELOAD_LOG
    for tool in hyprctl pkill swaync-client; do
        cat >"$STUB_BIN/$tool" <<EOF
#!/usr/bin/env bash
echo "$tool \$*" >>"\$RELOAD_LOG"
EOF
        chmod +x "$STUB_BIN/$tool"
    done
    printf '#!/usr/bin/env bash\nexit 0\n' >"$STUB_BIN/notify-send"
    chmod +x "$STUB_BIN/notify-send"
    export PATH="$STUB_BIN:$PATH"

    hypr="$XDG_CONFIG_HOME/hypr/conf.d/colors.dynamic.conf"

    # light: the module's ivory palette lands in the target files and the
    # module's single mode marker is written (not the legacy light-theme one).
    run "$REPO_ROOT/config/hypr/scripts/theme-mode.sh" light
    [ "$status" -eq 0 ]
    grep -q 'col.active_border = rgba(8c1220ff)' "$hypr"
    [ "$(cat "$XDG_CONFIG_HOME/hypr/palette-mode")" = light ]
    grep -qx 'hyprctl reload' "$RELOAD_LOG"

    run "$REPO_ROOT/config/hypr/scripts/theme-mode.sh" status
    [ "$status" -eq 0 ]
    [ "$output" = "light" ]

    # dark: the generated content is emptied again.
    run "$REPO_ROOT/config/hypr/scripts/theme-mode.sh" dark
    [ "$status" -eq 0 ]
    [ ! -s "$hypr" ]

    # toggle from dark reaches light through the module.
    run "$REPO_ROOT/config/hypr/scripts/theme-mode.sh" toggle
    [ "$status" -eq 0 ]
    [ -s "$hypr" ]
    [ "$(cat "$XDG_CONFIG_HOME/hypr/palette-mode")" = light ]
}

# The module carries three modes; this light/dark entry point collapses the
# non-light ones to dark for its own status output.
@test "theme-mode.sh status maps the dynamic mode to dark" {
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    mkdir -p "$XDG_CONFIG_HOME/hypr" "$BATS_TEST_TMPDIR/bin"
    printf 'dynamic\n' >"$XDG_CONFIG_HOME/hypr/palette-mode"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$BATS_TEST_TMPDIR/bin/notify-send"
    chmod +x "$BATS_TEST_TMPDIR/bin/notify-send"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"

    run "$REPO_ROOT/config/hypr/scripts/theme-mode.sh" status
    [ "$status" -eq 0 ]
    [ "$output" = "dark" ]
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
