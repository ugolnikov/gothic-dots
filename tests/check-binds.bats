#!/usr/bin/env bats
# Tests for scripts/check-binds.sh — the tsv coverage guard. Run with:
#
#   bats tests/
#
# The guard maps a few Hyprland key names to their tsv spelling (comma -> ",",
# slash -> "/"). These tests pin that mapping by running the guard against
# throwaway binds.conf/keybinds.tsv copies (CHECK_BINDS_BINDS / CHECK_BINDS_TSV),
# so the real config is never edited.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    CHECK="$REPO_ROOT/scripts/check-binds.sh"
    BINDS="$BATS_TEST_TMPDIR/binds.conf"
    TSV="$BATS_TEST_TMPDIR/keybinds.tsv"
    export CHECK_BINDS_BINDS="$BINDS" CHECK_BINDS_TSV="$TSV"

    # $mod must be defined and the dispatcher known; no scripts referenced.
    cat >"$BINDS" <<'EOF'
$mod = SUPER
bind = $mod, comma, togglesplit,
bind = $mod, slash, togglesplit,
EOF
}

@test "check-binds accepts comma and slash binds documented as , and /" {
    cat >"$TSV" <<'EOF'
`SUPER + ,`	settings
`SUPER + /`	keybind cheatsheet
EOF

    run "$CHECK"
    [ "$status" -eq 0 ]
}

@test "check-binds rejects a slash bind the table does not document" {
    cat >"$TSV" <<'EOF'
`SUPER + ,`	settings
EOF

    run "$CHECK"
    [ "$status" -eq 1 ]
    [[ "$output" == *"key 'slash'"* ]]
}
