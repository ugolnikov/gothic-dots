#!/usr/bin/env bash
# dotfiles-backup.sh — snapshot local dotfiles edits to the `snapshots` branch.
#
# Auto-snapshots used to land on the current branch and cluttered `main`'s
# history. Now each run builds a commit of the working tree with plumbing and
# pushes it to `origin/<branch>` (default `snapshots`), so `main` stays reserved
# for hand-written commits. The working tree and the current branch are never
# modified (only the index is used, then reset); a run on a clean tree exits
# without doing anything.
#
# Override the branch with DOTFILES_SNAPSHOT_BRANCH. It is safe to run by hand
# and is driven by the systemd timer (see README).
#
# Hardening: serialized with flock, logs to a state file, refuses to push
# anything that looks like a secret, and retries transient push failures
# (rebuilding on the new tip if the branch moved).
#
# Secrets never reach the remote: they live outside the repo and are covered by
# .gitignore (see README).

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

SNAPSHOT_BRANCH="${DOTFILES_SNAPSHOT_BRANCH:-snapshots}"

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

# git needs an identity to author a commit; fail clearly instead of cryptically.
if ! git config user.email >/dev/null 2>&1; then
    log "!! no git user.email configured; aborting"
    exit 1
fi

# Current snapshot tip (best effort — the branch may not exist yet).
tip=""
git fetch -q origin "$SNAPSHOT_BRANCH" 2>/dev/null || true
if git rev-parse --verify --quiet "refs/remotes/origin/$SNAPSHOT_BRANCH" >/dev/null 2>&1; then
    tip="$(git rev-parse "refs/remotes/origin/$SNAPSHOT_BRANCH")"
fi

# Stage the whole tree, then read it as a tree object. The real index is reset
# afterwards, so local edits are left exactly as they were (unstaged).
git add -A
tree="$(git write-tree)"

if [ -n "$tip" ] && [ "$tree" = "$(git rev-parse "$tip^{tree}")" ]; then
    git reset -q
    log "clean, nothing to back up"
    exit 0
fi

# Defense in depth: never push a secret that slipped past .gitignore.
if [ -x "$REPO/scripts/scan-secrets.sh" ]; then
    if ! "$REPO/scripts/scan-secrets.sh" --staged; then
        git reset -q
        log "!! secret scan failed; aborting (nothing pushed)"
        exit 1
    fi
fi

snapshot_msg="dotfiles: automatic snapshot $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Build the commit on top of the current tip without touching any branch.
make_commit() {
    if [ -n "$tip" ]; then
        git commit-tree "$tree" -p "$tip" -m "$snapshot_msg"
    else
        git commit-tree "$tree" -m "$snapshot_msg"
    fi
}
commit="$(make_commit)"

git reset -q

# Push with a few retries for transient network failures. If the branch moved,
# rebuild the commit on the new tip (and skip if the tree is already there).
for attempt in 1 2 3; do
    if git push -q origin "$commit:refs/heads/$SNAPSHOT_BRANCH"; then
        log "pushed $(git rev-parse --short "$commit") to origin/$SNAPSHOT_BRANCH"
        exit 0
    fi
    log "push attempt $attempt failed, retrying"
    sleep $((attempt * 5))
    git fetch -q origin "$SNAPSHOT_BRANCH" 2>/dev/null || true
    newtip="$(git rev-parse "refs/remotes/origin/$SNAPSHOT_BRANCH" 2>/dev/null || true)"
    if [ -n "$newtip" ] && [ "$newtip" != "$tip" ]; then
        if [ "$tree" = "$(git rev-parse "$newtip^{tree}")" ]; then
            log "snapshot already on origin/$SNAPSHOT_BRANCH"
            exit 0
        fi
        tip="$newtip"
        commit="$(make_commit)"
    fi
done

log "!! push failed after retries"
exit 1
