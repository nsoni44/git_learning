# Git/GitHub security — standards mapping

Distilled from NIST, CIS, MITRE ATT&CK, ISO/IEC 27001, and the EU NIS2 Directive,
mapped to concrete requirements for *this* tool (a GitHub SSH/GPG key auditor). Not a
copy of the standards — a translation of the parts that apply to key lifecycle, account
security, and CI/CD, with what this repo already does and what it doesn't.

Use this file when: setting/changing the "old key" threshold, deciding what
`quick_health_check` should flag, reviewing scope-escalation behavior, or arguing why a
check exists at all in a PR description.

## NIST

- **SP 800-57 Part 1 Rev. 5** (key management) — recommended crypto-period for
  asymmetric signing keys is **1–3 years**; shorter lifetimes are called for when data
  value, threat level, or regulatory context increase. This tool's
  `OLD_DAYS_THRESHOLD=365` (1 year) sits at the *aggressive* end of that range, which is
  appropriate for SSH keys authenticating to source control — treat 365 days as a
  floor, not something to relax upward. [nvlpubs.nist.gov/nistpubs/specialpublications/nist.sp.800-57pt1r5.pdf](https://nvlpubs.nist.gov/nistpubs/specialpublications/nist.sp.800-57pt1r5.pdf)
- **SP 800-218 (SSDF)** — expects version control systems to have "strong access
  controls" and expects release/commit integrity to be verifiable (code signing or
  equivalent). Maps directly to: GPG-signed commits/tags being audited alongside SSH
  keys (this tool already lists GPG keys; it does not currently check whether commits
  are *actually* signed, only whether a GPG key is registered — a gap). [csrc.nist.gov/pubs/sp/800/218/final](https://csrc.nist.gov/pubs/sp/800/218/final)
- **SP 800-63B** (digital identity) — underpins the MFA expectation reflected below
  in CIS/NIS2/ISO. `modules/account_security.sh`'s `check_2fa` implements this.

## CIS

- **CIS Controls v8, Control 5 (Account Management)** — lifecycle management of
  accounts/credentials from provisioning to deactivation so stale or orphaned
  credentials don't become entry points. Directly maps to `find_old_ssh_keys` /
  `delete_all_old_keys_batch` — this is the control this entire tool operationalizes.
- **CIS Controls v8, Control 6 (Access Control Management)** — least privilege for
  access rights. Maps to the `gh auth refresh` scope-widening issue flagged earlier in
  this project (`modules/account_security.sh`): requesting `admin:public_key
  admin:gpg_key user` scopes unconditionally on every run is the opposite of least
  privilege unless the user explicitly opted in for that run.
- **CIS GitHub Benchmark v1.0.0 / CIS Software Supply Chain Security Guide** — the
  GitHub-specific benchmark; source code management is called out as "the only source
  of truth for the rest of the [supply chain] process." Org-level checks include SSO,
  PAT policy, and Actions org policy; repo-level checks include branch protection,
  secret scanning, and CODEOWNERS. This repo already has CODEOWNERS and a
  branch-protection-adjacent auto-merge gate; it does not audit PAT policy at all
  (`pat_oauth_review.sh` explicitly notes the GitHub API can't list PATs and defers to
  manual review — a known, documented gap, not an oversight).
  [scribd.com/document/656364334/CIS-GitHub-Benchmark-v1-0-0-PDF](https://www.scribd.com/document/656364334/CIS-GitHub-Benchmark-v1-0-0-PDF)

## MITRE ATT&CK

- **T1552 Unsecured Credentials**, sub-technique **T1552.004 Private Keys** — adversaries
  search compromised systems for insecurely stored private keys. This is the direct
  threat model behind `secure_temp()`'s `chmod 600` + tracked cleanup (the bug fixed
  earlier — leaked temp files holding key material — was a live instance of exactly
  this exposure class, even though the leaked files held only public keys in practice).
  [attack.mitre.org/techniques/T1552/](https://attack.mitre.org/techniques/T1552/)
- **T1098 Account Manipulation**, sub-technique **T1098.001 Additional Cloud
  Credentials** — adversaries add their own SSH key to an account/instance to
  establish persistence without needing to reuse stolen credentials. This is *why*
  auditing "does this account have SSH keys I don't recognize" matters, not just "are
  keys old" — `list_ssh_keys_pretty` should be read by users looking for unrecognized
  `title` values, not just age. Worth a future enhancement: flag keys whose title
  doesn't match an allowlist the user maintains. [attack.mitre.org/techniques/T1098/](https://attack.mitre.org/techniques/T1098/)

## ISO/IEC 27001:2022

- **Annex A.5 (Organizational controls)** — A.5.15–5.18 cover access control,
  provisioning/de-provisioning, and access rights review — the governance layer this
  tool's audit log and batch-delete flow support.
- **Annex A.8 (Technological controls), 8.24 (Use of cryptography)** — cryptographic
  key management including generation, storage, and rotation policy. Maps to
  `parse_epoch`/key-age logic and the ed25519-preferred / RSA<4096-weak strength
  assessment in `list_ssh_keys_pretty`.
  [isms.online/iso-27001/annex-a-2022/8-24-use-of-cryptography-2022/](https://www.isms.online/iso-27001/annex-a-2022/8-24-use-of-cryptography-2022/)

## NIS2 Directive (EU), Article 21

Ten risk-management measure areas entities must implement, "appropriate and
proportionate" to risk. The two directly relevant here: **cryptography** (covering
data in transit/at rest/processing, "where appropriate") and **access
control policies**, alongside an explicit call-out for **multi-factor authentication**.
NIS2 applies to the entity operating an account, not to a personal script, but the
proportionality principle is a useful design lens: a solo-dev tool doesn't need
enterprise-grade controls, but it should not silently skip the ones that are cheap
(MFA check, audit log, least-privilege scopes) just because it's small.
[nis-2-directive.com/NIS_2_Directive_Article_21.html](https://www.nis-2-directive.com/NIS_2_Directive_Article_21.html)

## Bonus — OpenSSF (most directly applicable to this repo's CI, not requested but adjacent)

OpenSSF Scorecard checks that apply to `.github/workflows/*`: **Pinned-Dependencies**
(Actions pinned by SHA, not tag/floating version — this repo already does this for
`dependabot/fetch-metadata` in `dependabot-automerge.yml` but not for
`actions/checkout@v4` or `github/codeql-action@v3`, which are pinned by tag only),
**Branch-Protection**, and **Security-Policy** (already satisfied — `SECURITY.md`
exists). [github.com/ossf/scorecard](https://github.com/ossf/scorecard)

## Gap summary (as of 2026-07-13)

| Control area | Standard(s) | Status in this repo |
|---|---|---|
| Key age threshold | NIST 800-57 | OK — 365d is within/at the aggressive end of the 1-3yr range |
| Key strength (ed25519 > RSA≥4096) | ISO A.8.24 | Implemented in `list_ssh_keys_pretty` |
| Audit logging of mutations | ISO A.5.15-18, CIS 5 | Implemented via `audit_log` |
| Least-privilege token scopes | CIS 6 | **Gap** — `gh auth refresh` force-widens scopes unconditionally |
| Unrecognized-key detection (not just age) | MITRE T1098.001 | **Gap** — no allowlist/anomaly check on key titles |
| Commit signature verification (vs. just "GPG key exists") | NIST SSDF | **Gap** — GPG keys are listed, signatures aren't verified |
| PAT policy audit | CIS GitHub Benchmark | Documented gap (GitHub API limitation), not silent |
| Actions pinned by SHA | OpenSSF Scorecard | Partial — only `dependabot/fetch-metadata` is SHA-pinned |
| 2FA/MFA check | NIST 800-63B, NIS2 Art.21, ISO A.8.5 | Implemented in `modules/account_security.sh` |
