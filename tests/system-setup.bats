#!/usr/bin/env bats
# Tests for config/hypr/scripts/system-setup.sh — it lays etc/ out under the
# destination root, backs up a file it would overwrite, and enables the units.
# SYSTEM_SETUP_DEST points at a throwaway tree and sudo is a pass-through stub,
# so the tests never write to /etc and never need root.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    MODULE="$REPO_ROOT/config/hypr/scripts/system-setup.sh"

    export SYSTEM_SETUP_DEST="$BATS_TEST_TMPDIR/etc"
    mkdir -p "$SYSTEM_SETUP_DEST"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUB_BIN"
    export STUB_BIN CALLS
    export PATH="$STUB_BIN:$PATH"

    # Run the privileged step for real, just against the throwaway root.
    cat >"$STUB_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
    cat >"$STUB_BIN/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$CALLS"
EOF
    chmod +x "$STUB_BIN"/*
}

@test "every etc/ file lands at the same relative path under the destination" {
    run "$MODULE"
    [ "$status" -eq 0 ]

    while IFS= read -r -d '' src; do
        rel="${src#"$REPO_ROOT/etc"/}"
        [ -f "$SYSTEM_SETUP_DEST/$rel" ] || {
            echo "not installed: $rel" >&2
            return 1
        }
        cmp -s "$src" "$SYSTEM_SETUP_DEST/$rel" || {
            echo "content differs: $rel" >&2
            return 1
        }
    done < <(find "$REPO_ROOT/etc" -type f -print0)
}

@test "a file that would be overwritten is backed up first" {
    target="$SYSTEM_SETUP_DEST/systemd/oomd.conf"
    mkdir -p "$(dirname "$target")"
    printf 'local edit\n' >"$target"

    run "$MODULE"
    [ "$status" -eq 0 ]

    backup="$(find "$SYSTEM_SETUP_DEST/dotfiles-backup" -name oomd.conf -print -quit)"
    [ -n "$backup" ]
    grep -qx 'local edit' "$backup"
    cmp -s "$REPO_ROOT/etc/systemd/oomd.conf" "$target"
}

@test "an identical file is not backed up" {
    target="$SYSTEM_SETUP_DEST/systemd/oomd.conf"
    mkdir -p "$(dirname "$target")"
    cp "$REPO_ROOT/etc/systemd/oomd.conf" "$target"

    run "$MODULE"
    [ "$status" -eq 0 ]

    [ -z "$(find "$SYSTEM_SETUP_DEST/dotfiles-backup" -name oomd.conf -print -quit 2>/dev/null)" ]
}

@test "the services are enabled and zram is started" {
    run "$MODULE"
    [ "$status" -eq 0 ]

    grep -qx 'systemctl daemon-reload' "$CALLS"
    for svc in systemd-oomd.service ananicy-cpp.service irqbalance.service keyd.service; do
        grep -qx "systemctl enable --now $svc" "$CALLS"
    done
    grep -qx 'systemctl start systemd-zram-setup@zram0.service' "$CALLS"
}

@test "a missing etc/ directory is a no-op, not a failure" {
    tree="$BATS_TEST_TMPDIR/repo/config/hypr/scripts"
    mkdir -p "$tree"
    cp "$MODULE" "$tree/system-setup.sh"

    run "$tree/system-setup.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"нет "* ]]
}
