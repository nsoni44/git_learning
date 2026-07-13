# github-key-audit

Bash CLI that audits and rotates a GitHub account's SSH/GPG keys, PATs, and OAuth/App
authorizations via the `gh` CLI.

## Architecture

- `github_key_audit.sh` is the maintained entrypoint (v2.0). It is self-contained — it
  does NOT source anything from `modules/`.
- `modules/account_security.sh`, `modules/pat_oauth_review.sh`, `modules/ssh_gpg_audit.sh`
  are standalone scripts with overlapping functionality, run directly (there is no
  dispatcher). Don't assume a change to the root script propagates to them, or vice versa.
- Dependencies: `gh`, `jq`, `ssh-keygen`, `timeout`, `date`. `check_deps()` in the root
  script enforces this.

## Conventions (enforce these in any change)

- `set -euo pipefail` at the top of every script; quote every variable expansion.
- Date math must go through a GNU/BSD-portable helper (see `parse_epoch()` in the root
  script, mirrored in `modules/ssh_gpg_audit.sh`) — never call `date -d` directly, it
  breaks on macOS/BSD.
- Any temp file holding key material must go through `secure_temp()` in the root script,
  which tracks files in the `_TEMP_FILES` array and cleans them via a single top-level
  `EXIT` trap. Never add an ad-hoc `trap ... EXIT` inside a function — it clobbers the
  shared trap and leaks every prior temp file (this was a real bug, fixed 2026-07-13).
- Validate all user-supplied IDs/names (`validate_numeric`, `validate_keyname`) before
  passing them to `gh` or `ssh-keygen`.
- Every mutating action (key delete/add) must call `audit_log`.
- Never call `gh auth refresh` to widen token scopes without an explicit, separate
  user-facing confirmation — silently escalating a credential's scope is the one thing
  this tool must not do to its own users.

## Before calling a change done

- `bash -n <file>` must pass on every script touched.
- Run `shellcheck` on touched scripts if it's installed; fix warnings rather than
  suppressing them unless there's a documented reason.
- Manually trace new/changed menu options end-to-end — this is a bash CLI with no
  automated test suite yet, so nothing catches a broken flow but a real run.

## Compliance references

`.claude/references/git-security-standards.md` maps NIST/CIS/MITRE ATT&CK/ISO 27001/NIS2
guidance to this tool's specific behavior (key-age threshold, key-strength checks,
audit logging, scope minimization). Check it before changing `OLD_DAYS_THRESHOLD`,
the strength-assessment logic in `list_ssh_keys_pretty`, or anything touching `gh auth`
scopes — those values are chosen to satisfy specific external guidance, not arbitrary.

See `CONTRIBUTING.md` and `SECURITY.md` for process/reporting conventions.
