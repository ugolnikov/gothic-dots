#!/usr/bin/env bash
# dev-tools.sh — install the pinned local linters CI also runs.
#
#   scripts/dev-tools.sh
#
# Installs shfmt (the same pinned version CI uses) into ~/.local/bin and, when
# Node is available, markdownlint-cli2 at the pinned version globally. It is
# idempotent: an already-correct version is left alone. A missing npm is a
# warning, not a failure — the shell gates still work without the markdown
# linter.
set -euo pipefail

SHFMT_VERSION="v3.14.1"
MARKDOWNLINT_VERSION="0.23.2"
BIN_DIR="$HOME/.local/bin"

say() { printf '  %s\n' "$*"; }

mkdir -p "$BIN_DIR"

# Map the machine architecture to the Go release suffix shfmt publishes.
case "$(uname -m)" in
    x86_64 | amd64) shfmt_arch=amd64 ;;
    aarch64 | arm64) shfmt_arch=arm64 ;;
    *)
        echo "dev-tools: unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

# 1. shfmt — pinned to the same release as CI.
if [ -x "$BIN_DIR/shfmt" ] && [ "$("$BIN_DIR/shfmt" --version)" = "$SHFMT_VERSION" ]; then
    say "shfmt $SHFMT_VERSION already present in $BIN_DIR"
else
    url="https://github.com/mvdan/sh/releases/download/$SHFMT_VERSION/shfmt_${SHFMT_VERSION}_linux_${shfmt_arch}"
    say "installing shfmt $SHFMT_VERSION -> $BIN_DIR/shfmt"
    tmp="$(mktemp)"
    curl -fsSL -o "$tmp" "$url"
    install -m 0755 "$tmp" "$BIN_DIR/shfmt"
    rm -f "$tmp"
    say "installed shfmt $("$BIN_DIR/shfmt" --version)"
fi

# 2. markdownlint-cli2 — pinned like CI's action, installed via npm when Node
#    is present. Missing npm only warns: it does not fail the whole run.
if command -v npm >/dev/null 2>&1; then
    have="$(markdownlint-cli2 --version 2>/dev/null || true)"
    case "$have" in
        *"$MARKDOWNLINT_VERSION"*)
            say "markdownlint-cli2 $MARKDOWNLINT_VERSION already installed"
            ;;
        *)
            say "installing markdownlint-cli2@$MARKDOWNLINT_VERSION via npm"
            npm install -g "markdownlint-cli2@$MARKDOWNLINT_VERSION"
            ;;
    esac
else
    say "warning: npm not found — skipping markdownlint-cli2 (install Node to lint markdown locally)"
fi

# 3. Remind the user when the install directory is not on PATH yet.
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) say "warning: $BIN_DIR is not on your PATH — add it to use shfmt" ;;
esac
