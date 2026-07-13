"""Thin wrapper around `gh api graphql`.

Mirrors the gh_api() pattern in github_key_audit.sh: shell out to the
already-authenticated `gh` CLI instead of managing a token ourselves.
"""
import json
import subprocess

DEFAULT_TIMEOUT = 30


class GhApiError(RuntimeError):
    pass


def run_graphql(query: str, variables: dict, timeout: int = DEFAULT_TIMEOUT) -> dict:
    cmd = ["gh", "api", "graphql", "-f", f"query={query}"]
    for key, value in variables.items():
        if value is None:
            continue
        cmd += ["-F", f"{key}={value}"]

    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, check=False
        )
    except subprocess.TimeoutExpired as exc:
        raise GhApiError(f"gh api graphql timed out after {timeout}s") from exc
    except FileNotFoundError as exc:
        raise GhApiError("gh CLI not found on PATH") from exc

    if result.returncode != 0:
        raise GhApiError(f"gh api graphql failed: {result.stderr.strip()}")

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise GhApiError(
            f"gh api graphql returned non-JSON output: {result.stdout[:200]!r}"
        ) from exc

    if "errors" in payload:
        raise GhApiError(f"GraphQL errors: {payload['errors']}")

    return payload["data"]
