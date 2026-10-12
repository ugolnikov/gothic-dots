#!/usr/bin/env bash
# dotfiles-backup.sh — commit and push local dotfiles changes.
#
# The repository is the source of truth; this snapshots any local edits and
# pushes them. It is safe to run by hand and is driven by a systemd timer
# (see README), so a clean tree exits without doing anything.
#
# Secrets never reach the remote: they live outside the repo and are covered by
# .gitignore (see README).

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

# Nothing to do when the working tree is clean (tracked and untracked).
if git diff --quiet && git diff --cached --quiet &&
    [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo "dotfiles: clean, nothing to back up"
    exit 0
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
git add -A
git commit -q -m "dotfiles: automatic snapshot $(date -u +%Y-%m-%dT%H:%M:%SZ)"
git push -q origin "$branch"
echo "dotfiles: pushed $(git rev-parse --short HEAD) to origin/$branch"
