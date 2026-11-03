#!/usr/bin/env bats
# Tests for config/hypr/scripts/powermenu.sh — the rofi power menu maps the
# chosen row to exactly one action. rofi, hyprlock, hyprctl and systemctl are
# stubs, so nothing locks, exits or powers off the machine running the tests.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    MODULE="$REPO_ROOT/config/hypr/scripts/powermenu.sh"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    CALLS="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STUB_BIN"
    export STUB_BIN CALLS
    export PATH="$STUB_BIN:$PATH"

    # rofi prints whatever the test asked for, as the real menu would.
    cat >"$STUB_BIN/rofi" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null        # the menu list
printf '%s\n' "${ROFI_CHOICE:-}"
exit "${ROFI_RC:-0}"
EOF
    for tool in hyprlock hyprctl systemctl; do
        cat >"$STUB_BIN/$tool" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "$tool" "\$*" >>"\$CALLS"
EOF
    done
    chmod +x "$STUB_BIN"/*
}

@test "choosing lock runs hyprlock only" {
    export ROFI_CHOICE='󰌾  Блокировка'

    run "$MODULE"
    [ "$status" -eq 0 ]
    grep -qx 'hyprlock ' "$CALLS"
    [ "$(wc -l <"$CALLS")" -eq 1 ]
}

@test "choosing exit asks hyprctl to exit" {
    export ROFI_CHOICE='󰍃  Выход'

    run "$MODULE"
    [ "$status" -eq 0 ]
    grep -qx 'hyprctl dispatch exit' "$CALLS"
}

@test "choosing suspend goes through systemctl" {
    export ROFI_CHOICE='󰒲  Сон'

    run "$MODULE"
    [ "$status" -eq 0 ]
    grep -qx 'systemctl suspend' "$CALLS"
}

@test "choosing shutdown goes through systemctl" {
    export ROFI_CHOICE='󰐥  Выключение'

    run "$MODULE"
    [ "$status" -eq 0 ]
    grep -qx 'systemctl poweroff' "$CALLS"
}

# Dismissing the menu (no row, or a failing rofi) must be a quiet no-op rather
# than a crash under `set -e`.
@test "an empty selection does nothing" {
    run "$MODULE"
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "a cancelled rofi does nothing" {
    export ROFI_RC=1

    run "$MODULE"
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}
