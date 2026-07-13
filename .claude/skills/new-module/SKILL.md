---
name: new-module
description: Scaffold a new modules/<name>.sh file with this project's standard boilerplate (color vars, log/print_result helper, LOG_FILE convention, portable date helpers). Use when asked to add a new audit module so it doesn't ship as an empty stub like the ones removed on 2026-07-13.
---

When asked to add a new module under `modules/`:

1. Ask what the module audits if it isn't obvious from the request.
2. Create `modules/<name>.sh` using the same shape as `modules/ssh_gpg_audit.sh`:
   `#!/bin/bash`, a `LOG_DIR="logs"` + timestamped `LOG_FILE`, the
   `RED/GREEN/YELLOW/BLUE/NC` color vars, a `print_result()` helper, and — since this
   project has been bitten by non-portable date math before — the
   `parse_epoch`/`one_year_ago_epoch` helpers from `modules/ssh_gpg_audit.sh` if the
   module does any date comparison.
3. Never leave the file as an empty stub — if the module can't be fully implemented in
   one pass, write a real skeleton that runs and prints "not yet implemented" rather
   than a 0-byte file. Three empty stubs (`access_review.sh`, `actions_workflow_audit.sh`,
   `repo_security.sh`) shipped in this repo for an unknown amount of time before being
   deleted — don't repeat that.
4. Run `bash -n` on the new file before reporting done.
5. Note in your final summary that the module is standalone and not wired into
   `github_key_audit.sh`'s menu — ask whether the user wants a dispatcher, since none
   exists yet.
