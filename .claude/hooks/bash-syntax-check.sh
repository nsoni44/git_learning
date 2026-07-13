#!/usr/bin/env bash
# PostToolUse hook: after Edit|Write, block silently-broken bash syntax.
set -euo pipefail

input="$(cat)"
file="$(echo "$input" | jq -r '.tool_input.file_path // empty')"

if [[ -z "$file" || "$file" != *.sh || ! -f "$file" ]]; then
  exit 0
fi

if ! err="$(bash -n "$file" 2>&1)"; then
  jq -n --arg file "$file" --arg err "$err" \
    '{decision: "block", reason: ("bash -n failed for " + $file + ":\n" + $err)}'
fi
