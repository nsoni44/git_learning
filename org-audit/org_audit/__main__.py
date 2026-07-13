"""CLI entrypoint.

Usage: python -m org_audit --owner <login> [--owner-type org|user]
                            [--config PATH] [--format table|json] [--include-archived]
"""
import argparse
import sys
from pathlib import Path

from .gh import GhApiError
from .query import fetch_repos
from .report import to_json, to_table
from .rules import evaluate_repo, load_rules

DEFAULT_RULES_PATH = Path(__file__).resolve().parent.parent / "rules" / "baseline.yaml"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        prog="org-audit",
        description="Audit every repo an org/user owns against a branch-protection security baseline.",
    )
    parser.add_argument("--owner", required=True, help="GitHub org or user login to audit")
    parser.add_argument("--owner-type", choices=["org", "user"], default="org")
    parser.add_argument("--config", type=Path, default=DEFAULT_RULES_PATH,
                         help="Path to baseline rules YAML")
    parser.add_argument("--format", choices=["table", "json"], default="table")
    parser.add_argument("--include-archived", action="store_true",
                         help="Include archived repos (skipped by default)")
    args = parser.parse_args(argv)

    rules = load_rules(args.config)

    all_findings = []
    try:
        for repo in fetch_repos(args.owner, args.owner_type):
            if repo.get("isArchived") and not args.include_archived:
                continue
            all_findings.extend(evaluate_repo(repo, rules))
    except (GhApiError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    output = to_table(all_findings) if args.format == "table" else to_json(all_findings)
    print(output)

    fail_count = sum(1 for f in all_findings if f.status == "FAIL")
    return 1 if fail_count else 0


if __name__ == "__main__":
    sys.exit(main())
