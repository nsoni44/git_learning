---
name: compliance-check
description: Audit this repo's actual behavior against .claude/references/git-security-standards.md (NIST/CIS/MITRE ATT&CK/ISO 27001/NIS2 mapping) and report what's covered, what's gapped, and what changed since the reference was last updated. Use when asked for a compliance/standards review, before adding a new module, or when the gap table in the reference doc might be stale.
---

1. Read `.claude/references/git-security-standards.md` in full, especially the gap
   summary table at the end.
2. For each row in that table, re-verify the claim against the current code — don't
   trust the table blindly, it decays as the code changes:
   - Key age threshold: check `OLD_DAYS_THRESHOLD` in `github_key_audit.sh`.
   - Key strength assessment: check the strength logic in `list_ssh_keys_pretty`.
   - Audit logging: grep for `audit_log` calls around every mutating `gh` command
     (`ssh-key delete`, `ssh-key add`, `api -X DELETE`) in both the root script and
     `modules/`.
   - Least-privilege scopes: check whether `gh auth refresh` (in
     `modules/account_security.sh`) still force-widens scopes unconditionally.
   - GitHub Actions pinning: `grep -n "uses:" .github/workflows/*.yml` and check which
     actions are pinned by SHA vs. by tag (`@v4` is NOT a SHA pin).
   - 2FA/MFA check: confirm `check_2fa` in `modules/account_security.sh` still exists
     and is still called.
3. Report as a table: control area | standard | status | evidence (file:line). Flag any
   row where the code has drifted from what the reference doc claims — that means the
   reference doc itself needs an update, not just the code.
4. Do not silently "fix" gaps you find — this skill reports; fixing threshold/scope
   changes needs the user's sign-off since they're security-relevant tradeoffs, not
   style issues.
5. If asked to update the reference doc's gap table after a fix lands, edit only the
   table row that changed, not the framework summaries above it.
