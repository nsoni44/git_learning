# Security Policy

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Instead, email your findings to: **nsoni44@gmail.com**

Please include:
- Description of the vulnerability
- Steps to reproduce (if applicable)
- Potential impact
- Suggested fix (if you have one)

We take security seriously and will acknowledge your report within 48 hours.

---

## Security Updates

This repository implements multiple layers of security:

### 🔍 **Automated Code Scanning**
- **CodeQL** — Static code analysis for:
  - JavaScript, TypeScript, Python, Java, C++, C#, Go, Ruby
  - Security vulnerabilities and code quality issues
  - Runs on every push to `main`/`master`, PRs, and weekly

### 📦 **Dependency Management**
- **Dependabot** — Automated dependency updates for:
  - npm packages (daily checks)
  - Python/pip packages (daily checks)
  - GitHub Actions (daily checks)
  - Docker images (daily checks)
  - Maven/Java (daily checks)
- Auto-merges patch and minor version updates
- Alerts on security vulnerabilities

### 🔐 **Access Control**
- **CODEOWNERS** — Code owners review critical files:
  - `.github/workflows/` — Only repo owner can modify workflows
  - `.github/dependabot.yml` — Dependency config guarded
  - `package.json`, `requirements*.txt` — Dependency declarations protected

### 🚀 **CI/CD Security**
- **Auto-Merge Workflow** — Requires all status checks to pass before merge
- **Branch Protection** — Enforces quality gates
- **Keepalive Workflow** — Prevents accidental workflow auto-disable

### 🔑 **Key Management**
- Regular SSH/GPG key audits (manual via `github_key_audit.sh`)
- Recommend Ed25519 keys over RSA
- Identify and rotate keys older than 365 days

### 🚨 **Secret Scanning**
- GitHub Secret Scanning enabled (detects exposed credentials in pushes)
- Prevents accidental credential commits

---

## Security Best Practices

When contributing to this project:

1. ✅ **Use branch protection** — Never push directly to `master`
2. ✅ **Create PRs** — Let CodeQL and checks validate your changes
3. ✅ **Keep keys rotated** — Run `github_key_audit.sh` monthly
4. ✅ **Review Dependabot alerts** — Act on security updates
5. ✅ **Don't commit secrets** — Use GitHub secrets for sensitive data
6. ✅ **Verify signed commits** — Enable GPG signing (recommended)

---

## Response Timeline

| Finding | Response Time |
|---------|---------------|
| Critical vulnerability | 24 hours |
| High severity issue | 48 hours |
| Medium severity issue | 1 week |
| Low severity issue | Best effort |

---

## Credits

Thank you for helping keep this project secure! We appreciate responsible disclosure.
