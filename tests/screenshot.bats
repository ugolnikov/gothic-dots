#!/usr/bin/env bats
# Tests for config/hypr/scripts/screenshot.sh — capture, annotation and OCR.
# grim/slurp/tesseract/wl-copy notify-send satty swappy are stubs; the picture
# directory and runtime directory are throwaways.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    MODULE="$REPO_ROOT/config/hypr/scripts/screenshot.sh"
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    export XDG_PICTURES_DIR="$BATS_TEST_TMPDIR/pictures"
    export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/run"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME/hypr" "$XDG_RUNTIME_DIR"

    CALLS="$BATS_TEST_TMPDIR/calls.log"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    COPIED="$BATS_TEST_TMPDIR/copied"
    mkdir -p "$STUB_BIN"
    export CALLS STUB_BIN COPIED
    export PATH="$STUB_BIN:$PATH"

    cat >"$STUB_BIN/slurp" <<'EOF'
#!/usr/bin/env bash
[ "${SLURP_FAIL:-}" = 1 ] && exit 1
printf '10,20 100x50\n'
EOF
    cat >"$STUB_BIN/grim" <<'EOF'
#!/usr/bin/env bash
printf 'grim %s\n' "$*" >>"$CALLS"
for last; do :; done
printf 'png\n' >"$last"
EOF
    cat >"$STUB_BIN/wl-copy" <<'EOF'
#!/usr/bin/env bash
cat >"$COPIED"
printf 'wl-copy\n' >>"$CALLS"
EOF
    cat >"$STUB_BIN/notify-send" <<'EOF'
#!/usr/bin/env bash
printf 'notify-send %s\n' "$*" >>"$CALLS"
EOF
    cat >"$STUB_BIN/tesseract" <<'EOF'
#!/usr/bin/env bash
printf 'tesseract %s\n' "$*" >>"$CALLS"
[ "${TESS_EMPTY:-}" = 1 ] && exit 0
printf 'hello text\n'
EOF
    cat >"$STUB_BIN/satty" <<'EOF'
#!/usr/bin/env bash
printf 'satty %s\n' "$*" >>"$CALLS"
EOF
    cat >"$STUB_BIN/swappy" <<'EOF'
#!/usr/bin/env bash
printf 'swappy %s\n' "$*" >>"$CALLS"
EOF
    cat >"$STUB_BIN/hyprctl" <<'EOF'
#!/usr/bin/env bash
cat <<'JSON'
{"at":[10,20],"size":[800,600]}
JSON
EOF
    chmod +x "$STUB_BIN"/*
}

@test "a full screenshot lands in Pictures and on the clipboard" {
    run "$MODULE" full
    [ "$status" -eq 0 ]
    compgen -G "$XDG_PICTURES_DIR/Screenshots/*.png" >/dev/null
    grep -qx 'wl-copy' "$CALLS"
    grep -q 'notify-send' "$CALLS"
}

@test "a cancelled region changes nothing" {
    export SLURP_FAIL=1

    run "$MODULE" region
    [ "$status" -eq 0 ]
    [ ! -d "$XDG_PICTURES_DIR/Screenshots" ]
    [ ! -s "$CALLS" ]
}

@test "edit prefers satty over swappy" {
    run "$MODULE" region edit
    [ "$status" -eq 0 ]
    grep -q '^satty --filename ' "$CALLS"
    ! grep -q '^swappy' "$CALLS"
}

@test "edit falls back to swappy" {
    rm -f "$STUB_BIN/satty"

    run "$MODULE" region edit
    [ "$status" -eq 0 ]
    grep -q '^swappy -f ' "$CALLS"
}

@test "window capture asks Hyprland for the active geometry" {
    run "$MODULE" window
    [ "$status" -eq 0 ]
    grep -q 'grim -g 10,20 800x600 ' "$CALLS"
}

@test "OCR copies the recognized text and removes the temp image" {
    run "$MODULE" ocr
    [ "$status" -eq 0 ]
    [ "$(cat "$COPIED")" = "hello text" ]
    grep -q 'tesseract .* -l rus+eng' "$CALLS"
    [ -z "$(compgen -G "$XDG_RUNTIME_DIR/gothic-ocr.*" || true)" ]
}

@test "OCR honors the configured languages" {
    printf 'langs=eng\n' >"$XDG_CONFIG_HOME/hypr/ocr.conf"

    run "$MODULE" ocr
    [ "$status" -eq 0 ]
    grep -q 'tesseract .* -l eng' "$CALLS"
    ! grep -q 'rus+eng' "$CALLS"
}

@test "empty OCR result is reported and does not touch the clipboard" {
    export TESS_EMPTY=1

    run "$MODULE" ocr
    [ "$status" -eq 0 ]
    ! grep -q '^wl-copy' "$CALLS"
    grep -q 'текст не найден' "$CALLS"
}

@test "OCR without tesseract explains the missing package" {
    rm -f "$STUB_BIN/tesseract"

    run "$MODULE" ocr
    [ "$status" -eq 1 ]
    grep -q 'tesseract' "$CALLS"
}

@test "an unknown mode prints usage" {
    run "$MODULE" bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"usage:"* ]]
}
