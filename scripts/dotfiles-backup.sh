#!/usr/bin/env bash
# dotfiles-backup.sh — commit and push local dotfiles changes.
#
# The repository is the source of truth; this snapshots any local edits and
# pushes them. It is safe to run by hand and is driven by a systemd timer
# (see README), so a clean tree exits without doing anything.
#
# Hardening: serialized with flock, logs to a state file, refuses to push
# anything that looks like a secret, rebases onto origin before pushing and
# retries transient push failures.
#
# Secrets never reach the remote: they live outside the repo and are covered by
# .gitignore (see README).

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
mkdir -p "$STATE"
LOG="$STATE/dotfiles-backup.log"
log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$LOG"; }

# Serialize runs so a manual invocation and the timer never overlap.
if command -v flock >/dev/null 2>&1; then
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/dotfiles-backup.lock"
    if ! flock -n 9; then
        log "another run is in progress, exiting"
        exit 0
    fi
fi

# Nothing to do when the working tree is clean (tracked and untracked).
if git diff --quiet && git diff --cached --quiet &&
    [ -z "$(git ls-files --others --exclude-standard)" ]; then
    log "clean, nothing to back up"
    exit 0
fi

# git needs an identity to commit; fail clearly instead of a cryptic error.
if ! git config user.email >/dev/null 2>&1; then
    log "!! no git user.email configured; aborting"
    exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
git add -A

# Defense in depth: never push a secret that slipped past .gitignore.
if [ -x "$REPO/scripts/scan-secrets.sh" ]; then
    if ! "$REPO/scripts/scan-secrets.sh" --staged; then
        log "!! secret scan failed; aborting (changes left staged)"
        exit 1
    fi
fi

git commit -q -m "dotfiles: automatic snapshot $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Rebase onto origin if it moved (keeps the push a fast-forward).
if git rev-parse --verify --quiet "refs/remotes/origin/$branch" >/dev/null; then
    if ! git pull --rebase --autostash --quiet origin "$branch"; then
        log "!! pull --rebase failed; resolve manually"
        exit 1
    fi
fi

# Push with a few retries for transient network failures.
for attempt in 1 2 3; do
    if git push -q origin "$branch"; then
        log "pushed $(git rev-parse --short HEAD) to origin/$branch"
        exit 0
    fi
    log "push attempt $attempt failed, retrying"
    sleep $((attempt * 5))
done

log "!! push failed after retries"
exit 1
