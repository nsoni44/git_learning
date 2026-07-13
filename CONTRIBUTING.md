# Contributing to git_learning

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## Code of Conduct

Be respectful and inclusive. Harassment, discrimination, and disruptive behavior are not tolerated.

## How to Contribute

### Reporting Issues

- **Security vulnerabilities**: Email nsoni44@gmail.com (see [SECURITY.md](.github/SECURITY.md))
- **Bugs**: Open a GitHub Issue with:
  - Clear description
  - Steps to reproduce
  - Expected vs. actual behavior
  - Environment details (OS, version)

- **Feature requests**: Open a GitHub Issue with:
  - Clear use case
  - Why it's needed
  - Proposed implementation (if you have ideas)

### Contributing Code

1. **Fork** the repository
2. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**:
   - Follow existing code style
   - Keep commits atomic and well-messaged
   - Write descriptive commit messages

4. **Commit with proper messages**:
   ```bash
   git commit -m "feat: add feature" 
   git commit -m "fix: resolve issue"
   git commit -m "docs: update README"
   ```

5. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request**:
   - Reference related issues
   - Explain what and why
   - Include testing details

### Pull Request Process

1. **Automated checks must pass**:
   - CodeQL security scanning
   - All status checks
   - Branch is up to date

2. **Code review** (if applicable):
   - Changes to security files (`CODEOWNERS`, workflows) require review
   - Be open to feedback

3. **Auto-merge** (after checks pass):
   - PRs merge automatically once all checks pass
   - Feature branches are deleted automatically

## Development Setup

### Prerequisites
- Bash shell (bash 4.0+)
- GitHub CLI (`gh`)
- jq (for JSON parsing)
- openssh-client (for SSH key tools)

### Optional Tools
- `git-crypt` for secrets management
- `pre-commit` for local hook management

### Key Files
- `.github/workflows/` — CI/CD automation
- `.github/dependabot.yml` — Dependency update config
- `.github/CODEOWNERS` — File ownership rules
- `github_key_audit.sh` — SSH/GPG key auditor

### Audit SSH Keys

Before committing, audit your keys:
```bash
chmod +x github_key_audit.sh
./github_key_audit.sh
```

## Commit Message Guidelines

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `security`

**Examples**:
```bash
git commit -m "feat: add CodeQL workflow for security scanning"
git commit -m "fix: resolve duplicate CodeQL configuration"
git commit -m "docs: add SECURITY.md policy"
git commit -m "chore: update dependencies"
git commit -m "security: rotate SSH keys"
```

## Testing

Before opening a PR:
1. Test your changes locally
2. Run relevant tools (CodeQL, linters)
3. Verify no sensitive data is committed

### Checking for Secrets

```bash
# GitHub CLI checks for secrets before push
gh secret-scanning alerts --repository nsoni44/git_learning
```

## Code Style

- **Bash**: ShellCheck compliant, POSIX compatible where possible
- **YAML**: 2-space indentation, consistent formatting
- **Comments**: Clear, explain the "why", not just the "what"

## Documentation

- Update README.md for major changes
- Document public functions/scripts
- Include examples where helpful
- Keep CHANGELOG.md updated (if applicable)

## Security Considerations

- ✅ Never commit secrets, API keys, or credentials
- ✅ Use GitHub Secrets for sensitive data in workflows
- ✅ Rotate SSH/GPG keys regularly
- ✅ Review Dependabot alerts promptly
- ✅ Keep dependencies up to date

## Questions?

- Check existing issues/PRs
- Review documentation
- Email: nsoni44@gmail.com

## License

By contributing, you agree your code will be licensed under the MIT License.

---

Thank you for contributing! 🎉
