# Security

This is a personal dotfiles repository: configuration files, a handful of shell
helpers and CI. It is not meant to hold any credentials.

## Reporting

Please report a problem privately through GitHub — **Security → Report a
vulnerability** — rather than a public issue.

## Secrets

Nothing secret belongs in the tree. Keys live outside the repo in
`~/.secrets.fish` and `~/.secrets.sh`, both covered by `.gitignore`. Two guards
help keep it that way:

* `scripts/scan-secrets.sh` scans the tree for credential shapes (`--all`);
* the `pre-commit` / `pre-push` hooks and CI run it on every change.

If a secret does land in a commit, rotate it first, then rewrite it out of
history with `git filter-repo`.
