#!/usr/bin/env bats
# Tests for install.sh as a consumer of scripts/link-plan.sh: installing links
# exactly the plan's pairs and uninstalling removes exactly the plan's
# destinations. Every test redirects HOME to a throwaway tree under
# $BATS_TEST_TMPDIR and stubs the steps that would reach the network, the
# desktop or the repo's git config, so the real home directory is never touched.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    cd "$REPO_ROOT"
}

# setup_throwaway_home — point HOME at a fresh tree and neuter the installer's
# non-linking side effects (font/bat caches, vim-plug download, systemd, git
# hooks) with no-op stubs on PATH. The tests then observe only the symlink set.
setup_throwaway_home() {
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"

    local stub="$BATS_TEST_TMPDIR/stub-bin" tool
    mkdir -p "$stub"
    for tool in fc-cache bat vim systemctl pacman git getent sudo curl; do
        printf '#!/usr/bin/env bash\nexit 0\n' >"$stub/$tool"
        chmod +x "$stub/$tool"
    done
    export PATH="$stub:$PATH"
}

# Regression: the installer links the plan's pairs, not a hand-kept list.
# Pointing the plan at a throwaway tree (LINK_PLAN_ROOT) must redirect what
# install.sh links; a duplicate enumeration in the installer would ignore it.
@test "install.sh links exactly the pairs the plan prints" {
    tree="$BATS_TEST_TMPDIR/tree"
    mkdir -p "$tree/config/present" "$tree/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$tree/bin/tool"
    chmod +x "$tree/bin/tool"

    export LINK_PLAN_ROOT="$tree"
    setup_throwaway_home

    run ./install.sh --no-packages
    [ "$status" -eq 0 ]

    [ -L "$HOME/.config/present" ]
    [ "$(readlink -f "$HOME/.config/present")" = "$tree/config/present" ]
    [ -L "$HOME/.local/bin/tool" ]
    # Nothing outside the plan is linked.
    [ ! -e "$HOME/.config/hypr" ]
}

@test "install.sh installs exactly the plan's destinations" {
    setup_throwaway_home

    run ./install.sh --no-packages
    [ "$status" -eq 0 ]

    # Expected: every destination the plan names. Actual: every symlink under
    # the throwaway home that points back into this repository.
    ./scripts/link-plan.sh | cut -f2 | sort >"$BATS_TEST_TMPDIR/planned"
    find "$HOME" -type l -lname "$REPO_ROOT/*" -print | sort >"$BATS_TEST_TMPDIR/installed"
    diff -u "$BATS_TEST_TMPDIR/planned" "$BATS_TEST_TMPDIR/installed"
}

@test "install.sh --uninstall removes exactly the plan's destinations" {
    setup_throwaway_home
    ./scripts/link-plan.sh >"$BATS_TEST_TMPDIR/plan"

    run ./install.sh --no-packages
    [ "$status" -eq 0 ]

    # Foreign files that are not our symlinks must survive the uninstall.
    mkdir -p "$HOME/.config" "$HOME/.local/bin"
    printf 'mine\n' >"$HOME/.config/keep.conf"
    printf '#!/bin/sh\n' >"$HOME/.local/bin/mine"

    # The un-dotted repo files land under dotted targets and must be found.
    [ -L "$HOME/.gitconfig" ]
    [ -L "$HOME/.tmux.conf" ]

    run ./install.sh --uninstall
    [ "$status" -eq 0 ]

    local src dst
    while IFS=$'\t' read -r src dst; do
        [ -n "$dst" ] || continue
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            echo "uninstall left $dst behind" >&2
            return 1
        fi
    done <"$BATS_TEST_TMPDIR/plan"

    [ -f "$HOME/.config/keep.conf" ]
    [ -f "$HOME/.local/bin/mine" ]

    run find "$HOME" -type l -lname "$REPO_ROOT/*"
    [ -z "$output" ]
}

# Uninstall reads the same plan as install, so --only narrows it the same way:
# only that app's link goes, and its siblings stay.
@test "install.sh --uninstall --only removes only that app's link" {
    setup_throwaway_home

    run ./install.sh --no-packages
    [ "$status" -eq 0 ]
    [ -L "$HOME/.config/hypr" ]
    [ -L "$HOME/.config/waybar" ]

    run ./install.sh --uninstall --only hypr
    [ "$status" -eq 0 ]

    [ ! -e "$HOME/.config/hypr" ]
    [ -L "$HOME/.config/waybar" ]
}
