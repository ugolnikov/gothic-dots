#!/usr/bin/env bats
# Tests for scripts/doctor.sh — its symlink section is derived from the link
# plan (scripts/link-plan.sh), so it covers every planned destination and
# reports each as present, missing or foreign. HOME is a throwaway tree; the
# real home directory is never touched.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME/.config" "$HOME/.local/bin"
}

# link_plan — the plan as `src<TAB>dst` lines, read against the throwaway $HOME.
link_plan() {
    "$REPO_ROOT/scripts/link-plan.sh"
}

# symlink_all_planned — recreate every planned link under the throwaway HOME.
symlink_all_planned() {
    local src dst
    while IFS=$'\t' read -r src dst; do
        [ -n "$dst" ] || continue
        mkdir -p "$(dirname "$dst")"
        ln -sfnT "$src" "$dst"
    done < <(link_plan)
}

# state_of <dst> — present / missing / foreign / unreported, read from the
# doctor run captured in $output.
state_of() {
    local dst="$1" line
    line="$(printf '%s\n' "$output" | grep -F -- "$dst" | head -n 1 || true)"
    case "$line" in
        "") printf 'unreported\n' ;;
        *"отсутствует"*) printf 'missing\n' ;;
        *"не из репозитория"*) printf 'foreign\n' ;;
        *) printf 'present\n' ;;
    esac
}

@test "doctor.sh checks every destination in the link plan" {
    symlink_all_planned

    run "$REPO_ROOT/scripts/doctor.sh"

    local src dst
    while IFS=$'\t' read -r src dst; do
        [ -n "$dst" ] || continue
        [ "$(state_of "$dst")" = present ] || {
            echo "doctor did not report the planned link $dst (got $(state_of "$dst"))" >&2
            return 1
        }
    done < <(link_plan)
}

@test "doctor.sh reports a planned link that is missing" {
    symlink_all_planned
    rm -f "$HOME/.tmux.conf"

    run "$REPO_ROOT/scripts/doctor.sh"

    [ "$(state_of "$HOME/.tmux.conf")" = missing ]
    [ "$(state_of "$HOME/.config/hypr")" = present ]
}

@test "doctor.sh reports a planned link that points outside the repository" {
    symlink_all_planned
    printf 'not ours\n' >"$BATS_TEST_TMPDIR/foreign"
    ln -sfnT "$BATS_TEST_TMPDIR/foreign" "$HOME/.vimrc"

    run "$REPO_ROOT/scripts/doctor.sh"

    [ "$(state_of "$HOME/.vimrc")" = foreign ]
}

@test "doctor.sh still covers the helper binaries directory" {
    symlink_all_planned

    run "$REPO_ROOT/scripts/doctor.sh"

    [ "$(state_of "$HOME/.local/bin/please")" = present ]
}
