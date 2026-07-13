# org-audit

Org-wide branch-protection / config posture scanner. Audits every repo an org (or
user account) owns against a declarative security baseline
(`rules/baseline.yaml`), and reports pass/fail per rule with the standard
(NIST/CIS/ISO/etc.) each rule maps back to — see
`../.claude/references/git-security-standards.md` for the full mapping.

This is the org-wide generalization of `../github_key_audit.sh`'s per-account key
auditing: same philosophy (audit, don't silently trust), applied to repo
configuration instead of SSH/GPG keys.

## Requirements

- Python 3.9+
- [`gh`](https://cli.github.com/) CLI, already authenticated (`gh auth status`).
  This tool shells out to `gh api graphql` — it never handles a token directly.
- A `gh` token with `read:org` and `repo` scopes to see branch protection data.
  Some fields may come back as unreadable without sufficient scope; those are
  reported as FAIL with an explicit "insufficient permission" reason, not silently
  skipped.

## Setup

```sh
cd org-audit
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

## Usage

```sh
# Audit every repo an organization owns
.venv/bin/python -m org_audit --owner my-org --owner-type org

# Audit your own account's repos (no org-admin rights needed)
.venv/bin/python -m org_audit --owner my-username --owner-type user

# Machine-readable output
.venv/bin/python -m org_audit --owner my-org --format json

# Use a custom baseline
.venv/bin/python -m org_audit --owner my-org --config /path/to/custom.yaml
```

Exit code is `1` if any check fails, `0` if everything passes — safe to wire into CI.

## Editing the baseline

`rules/baseline.yaml` is the whole policy. Each rule is declarative:

```yaml
- id: admin_enforced
  description: "Branch protection must apply to admins (no bypass)"
  standard: "CIS Controls v8, Control 6 (Access Control Management / least privilege)"
  field: isAdminEnforced
  check: is_true
```

`check` is one of `exists`, `is_true`, `is_false`, `min_value` (needs a `value:`
field too). Add a rule by adding a YAML entry — no code changes needed.

## Tests

```sh
.venv/bin/python -m unittest discover -s tests -t .
```

Tests run against fixture JSON in `tests/fixtures/` — no live API calls, no `gh`
auth needed.
