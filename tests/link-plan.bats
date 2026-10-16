#!/usr/bin/env bats
# Tests for scripts/link-plan.sh — the single definition of what this repo
# links where. The plan is driven at its output seam: absolute `src<TAB>dst`
# pairs, one per line. HOME is a throwaway tree under the test tmpdir; the real
# home directory is never touched.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    PLAN="$REPO_ROOT/scripts/link-plan.sh"

    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
}

# plan_line <src> <dst> — the exact line the plan must print for one link.
plan_line() {
    printf '%s\t%s\n' "$1" "$2"
}

@test "link-plan.sh prints every config dir as ~/.config/<name>" {
    "$PLAN" >"$BATS_TEST_TMPDIR/plan"
    [ "$?" -eq 0 ]

    local d name
    for d in "$REPO_ROOT"/config/*/; do
        name="$(basename "$d")"
        grep -qxF "$(plan_line "${d%/}" "$HOME/.config/$name")" "$BATS_TEST_TMPDIR/plan" ||
            {
                echo "missing link for config/$name" >&2
                return 1
            }
    done
}

@test "link-plan.sh covers every special case" {
    "$PLAN" >"$BATS_TEST_TMPDIR/plan"

    # A config file that is not a directory.
    grep -qxF "$(plan_line "$REPO_ROOT/config/starship.toml" "$HOME/.config/starship.toml")" "$BATS_TEST_TMPDIR/plan"
    # Un-dotted repo files linked under dotted home targets.
    grep -qxF "$(plan_line "$REPO_ROOT/tmux.conf" "$HOME/.tmux.conf")" "$BATS_TEST_TMPDIR/plan"
    grep -qxF "$(plan_line "$REPO_ROOT/gitconfig" "$HOME/.gitconfig")" "$BATS_TEST_TMPDIR/plan"
    grep -qxF "$(plan_line "$REPO_ROOT/.vimrc" "$HOME/.vimrc")" "$BATS_TEST_TMPDIR/plan"
    grep -qxF "$(plan_line "$REPO_ROOT/.editorconfig" "$HOME/.editorconfig")" "$BATS_TEST_TMPDIR/plan"
    # Shell dotfiles.
    grep -qxF "$(plan_line "$REPO_ROOT/bash/.bashrc" "$HOME/.bashrc")" "$BATS_TEST_TMPDIR/plan"
    grep -qxF "$(plan_line "$REPO_ROOT/bash/.profile" "$HOME/.profile")" "$BATS_TEST_TMPDIR/plan"
    # Config directory outside the app-config tree.
    grep -qxF "$(plan_line "$REPO_ROOT/fish" "$HOME/.config/fish")" "$BATS_TEST_TMPDIR/plan"
    # claude is a file, not a whole directory.
    grep -qxF "$(plan_line "$REPO_ROOT/claude/settings.json" "$HOME/.claude/settings.json")" "$BATS_TEST_TMPDIR/plan"
    # Helper binaries directory.
    local b
    for b in "$REPO_ROOT"/bin/*; do
        grep -qxF "$(plan_line "$b" "$HOME/.local/bin/$(basename "$b")")" "$BATS_TEST_TMPDIR/plan"
    done
}

@test "link-plan.sh --only prints just the named config app" {
    run "$PLAN" --only hypr
    [ "$status" -eq 0 ]
    [ "$output" = "$(plan_line "$REPO_ROOT/config/hypr" "$HOME/.config/hypr")" ]
}

@test "link-plan.sh --only accepts a comma-separated list" {
    run "$PLAN" --only hypr,waybar
    [ "$status" -eq 0 ]
    [[ "$output" == *"$REPO_ROOT/config/hypr"$'\t'"$HOME/.config/hypr"* ]]
    [[ "$output" == *"$REPO_ROOT/config/waybar"$'\t'"$HOME/.config/waybar"* ]]
    [[ "$output" != *"$HOME/.config/kitty"* ]]
}

@test "link-plan.sh --only starship prints the config file, not a dir" {
    run "$PLAN" --only starship
    [ "$status" -eq 0 ]
    [ "$output" = "$(plan_line "$REPO_ROOT/config/starship.toml" "$HOME/.config/starship.toml")" ]
}

@test "link-plan.sh --only skips the home dotfiles, fish, claude and bin" {
    run "$PLAN" --only hypr
    [ "$status" -eq 0 ]
    [[ "$output" != *"$HOME/.tmux.conf"* ]]
    [[ "$output" != *"$HOME/.bashrc"* ]]
    [[ "$output" != *"$HOME/.config/fish"* ]]
    [[ "$output" != *"$HOME/.claude/settings.json"* ]]
    [[ "$output" != *"$HOME/.local/bin/"* ]]
}

@test "link-plan.sh --only needs a non-empty list" {
    run "$PLAN" --only
    [ "$status" -eq 2 ]
}

@test "link-plan.sh output order is stable across runs" {
    "$PLAN" >"$BATS_TEST_TMPDIR/plan1"
    "$PLAN" >"$BATS_TEST_TMPDIR/plan2"
    diff -u "$BATS_TEST_TMPDIR/plan1" "$BATS_TEST_TMPDIR/plan2"
}

@test "link-plan.sh omits a link whose source does not exist" {
    # Point the module at a throwaway tree that has one config dir but not the
    # other: the plan is built from what is really there, so a source that is
    # missing (or a stale entry) is never printed.
    tree="$BATS_TEST_TMPDIR/tree"
    mkdir -p "$tree/config/present" "$tree/bin"
    printf '#!/usr/bin/env bash\n' >"$tree/bin/tool"

    run env LINK_PLAN_ROOT="$tree" "$PLAN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$tree/config/present"$'\t'"$HOME/.config/present"* ]]
    [[ "$output" == *"$tree/bin/tool"$'\t'"$HOME/.local/bin/tool"* ]]
    [[ "$output" != *"missing"* ]]
}

# Regression: the plan is the single definition of the link set. Until
# install.sh consumes it (its own ticket), they must still agree, so the
# module can never silently drop a link the installer creates.
@test "link-plan.sh reproduces exactly the set install.sh links" {
    "$PLAN" | sort >"$BATS_TEST_TMPDIR/plan"

    run "$REPO_ROOT/install.sh" --no-packages --dry-run
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" |
        awk '/ln -sfnT/ {print $3 "\t" $4}' | sort >"$BATS_TEST_TMPDIR/install"

    diff -u "$BATS_TEST_TMPDIR/install" "$BATS_TEST_TMPDIR/plan"
}
