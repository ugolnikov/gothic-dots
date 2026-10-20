#!/usr/bin/env bats
# Tests for scripts/maintenance.sh — local snapshots, diff, rollback and the
# update flow. Run with:
#
#   bats tests/
#
# The script runs against a throwaway git repo (MAINT_ROOT) with a throwaway
# snapshot store (MAINT_STATE); pacman/sudo/doctor are stubs, so no package is
# ever touched and the real checkout is never the target.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    MAINT="$REPO_ROOT/scripts/maintenance.sh"
    ROOT="$BATS_TEST_TMPDIR/repo"
    export MAINT_ROOT="$ROOT"
    export MAINT_STATE="$BATS_TEST_TMPDIR/snapshots"
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME" "$ROOT/config/hypr" "$ROOT/fish" "$ROOT/scripts"

    CALLS="$BATS_TEST_TMPDIR/calls.log"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    PKG_STATE="$BATS_TEST_TMPDIR/packages"
    mkdir -p "$STUB_BIN"
    export CALLS PKG_STATE
    export PATH="$STUB_BIN:$PATH"

    printf 'alpha 1.0\nbeta 2.0\n' >"$PKG_STATE"
    printf 'general { gaps_in = 4 }\n' >"$ROOT/config/hypr/hyprland.conf"
    printf 'set -g fish_greeting\n' >"$ROOT/fish/config.fish"
    git -C "$ROOT" init -q
    git -C "$ROOT" add -A
    git -C "$ROOT" -c user.name=test -c user.email=test@example.com commit -qm init

    cat >"$ROOT/scripts/doctor.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "doctor" >>"\$CALLS"
EOF
    chmod +x "$ROOT/scripts/doctor.sh"

    cat >"$STUB_BIN/pacman" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    -Q) cat "$PKG_STATE" ;;
    -Qtdq) : ;;
    *) printf 'pacman%s\n' "${*:+ $*}" >>"$CALLS" ;;
esac
EOF
    cat >"$STUB_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"$CALLS"
exec "$@"
EOF
    cat >"$STUB_BIN/journalctl" <<'EOF'
#!/usr/bin/env bash
printf 'Archived and active journals take up 12.0M\n'
EOF
    chmod +x "$STUB_BIN"/*
}

@test "snapshot stores configs, packages and the commit" {
    run "$MAINT" snapshot first
    [ "$status" -eq 0 ]
    [ "$output" = first ]
    [ -s "$MAINT_STATE/first/config.tar.gz" ]
    grep -qx 'alpha 1.0' "$MAINT_STATE/first/packages.txt"
    [ -s "$MAINT_STATE/first/sha" ]
    [ -s "$MAINT_STATE/first/created" ]
    tar -tzf "$MAINT_STATE/first/config.tar.gz" | grep -qx 'config/hypr/hyprland.conf'
}

@test "snapshots lists what is stored" {
    "$MAINT" snapshot first >/dev/null
    run "$MAINT" snapshots
    [ "$status" -eq 0 ]
    [[ "$output" == *"first"* ]]
}

@test "diff reports package and file changes since a snapshot" {
    "$MAINT" snapshot base >/dev/null
    printf 'general { gaps_in = 8 }\n' >"$ROOT/config/hypr/hyprland.conf"
    printf 'alpha 2.0\ngamma 3.0\n' >"$PKG_STATE"

    run "$MAINT" diff base
    [ "$status" -eq 0 ]
    [[ "$output" == *"upgraded alpha 1.0 -> 2.0"* ]]
    [[ "$output" == *"added    gamma 3.0"* ]]
    [[ "$output" == *"removed  beta 2.0"* ]]
    [[ "$output" == *"config/hypr/hyprland.conf"* ]]
}

@test "rollback --dry-run only prints the plan" {
    "$MAINT" snapshot base >/dev/null
    printf 'changed\n' >"$ROOT/config/hypr/hyprland.conf"

    run "$MAINT" rollback base --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"план:"* ]]
    grep -qx 'changed' "$ROOT/config/hypr/hyprland.conf"
}

@test "rollback restores the snapshot and keeps a pre-rollback copy" {
    "$MAINT" snapshot base >/dev/null
    printf 'changed\n' >"$ROOT/config/hypr/hyprland.conf"

    run "$MAINT" rollback base
    [ "$status" -eq 0 ]
    grep -qx 'general { gaps_in = 4 }' "$ROOT/config/hypr/hyprland.conf"
    find "$MAINT_STATE" -maxdepth 1 -type d -name 'pre-rollback-*' | grep -q .
}

@test "update --dry-run prints the plan and runs nothing" {
    run "$MAINT" update --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"sudo pacman -Syu"* ]]
    ! grep -q '^sudo ' "$CALLS"
    [ ! -d "$MAINT_STATE/pre-update-$(date +%Y%m%d)" ] || true
    [ -z "$(find "$MAINT_STATE" -maxdepth 1 -name 'pre-update-*' 2>/dev/null)" ]
}

@test "update snapshots first, then updates and runs doctor" {
    run "$MAINT" update
    [ "$status" -eq 0 ]
    grep -qx 'sudo pacman -Syu' "$CALLS"
    grep -qx 'pacman -Syu' "$CALLS"
    grep -qx 'doctor' "$CALLS"
    [ -n "$(find "$MAINT_STATE" -maxdepth 1 -type d -name 'pre-update-*')" ]
    [[ "$output" == *"== пакеты с момента"* ]]
}

@test "a dirty tree is refused without --force" {
    printf 'dirty\n' >>"$ROOT/config/hypr/hyprland.conf"

    run "$MAINT" update
    [ "$status" -eq 2 ]
    [[ "$output" == *"грязное"* ]]
    ! grep -q '^sudo ' "$CALLS"

    run "$MAINT" update --force
    [ "$status" -eq 0 ]
    grep -qx 'sudo pacman -Syu' "$CALLS"
}

@test "clean reports and deletes nothing" {
    run "$MAINT" clean
    [ "$status" -eq 0 ]
    [[ "$output" == *"ничего не удалено"* ]]
    [[ "$output" == *"журнал"* ]]
}

@test "rollback refuses a name with no snapshot" {
    run "$MAINT" rollback ghost
    [ "$status" -eq 2 ]
    [[ "$output" == *"нет снимка"* ]]
}

@test "an unknown command prints usage" {
    run "$MAINT" bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
