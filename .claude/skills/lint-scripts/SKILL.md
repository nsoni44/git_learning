---
name: lint-scripts
description: Run bash -n and shellcheck (if installed) across every .sh file in this repo and report syntax errors and warnings. Use before committing changes to github_key_audit.sh or modules/*.sh, or when asked to lint/check the shell scripts.
---

Run this over every `.sh` file in the repo (root script + `modules/`):

1. `bash -n <file>` for a syntax check — this must pass on every file, no exceptions.
2. If `shellcheck` is on PATH, run `shellcheck <file>` and report warnings; if it's
   missing, say so once and suggest `brew install shellcheck` (macOS) or
   `apt install shellcheck` (Ubuntu) rather than silently skipping.
3. Cross-check against CLAUDE.md's conventions: portable date parsing, the shared
   temp-file trap, input validation before `gh`/`ssh-keygen` calls, `audit_log` on
   mutations.
4. Summarize as a per-file pass/fail list. Do not auto-fix anything beyond trivial,
   obviously-safe issues (e.g. missing quotes) without asking — mutation logic and
   API-call ordering need a human look.
