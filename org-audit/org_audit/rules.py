"""Loads rules/baseline.yaml and evaluates repos against it.

Any field that comes back null/missing from the GitHub API (insufficient token
permission, or no branch protection at all) is treated as a FAIL with an explicit
"not configured / unverifiable" reason — never silently skipped.
"""
from dataclasses import dataclass
from pathlib import Path

import yaml


@dataclass
class Finding:
    repo: str
    rule_id: str
    description: str
    standard: str
    status: str  # "PASS" | "FAIL"
    reason: str


def load_rules(path: Path) -> list:
    with open(path, "r") as f:
        data = yaml.safe_load(f)
    return data["rules"]


def _get_protection_rule(repo: dict):
    default_branch_ref = repo.get("defaultBranchRef")
    if not default_branch_ref:
        return None
    return default_branch_ref.get("branchProtectionRule")


def evaluate_repo(repo: dict, rules: list) -> list:
    findings = []
    protection = _get_protection_rule(repo)
    repo_name = repo["name"]

    for rule in rules:
        rule_id = rule["id"]
        description = rule["description"]
        standard = rule["standard"]
        check = rule["check"]

        if check == "exists":
            if protection is not None:
                findings.append(Finding(repo_name, rule_id, description, standard,
                                         "PASS", "branch protection rule present"))
            else:
                findings.append(Finding(repo_name, rule_id, description, standard,
                                         "FAIL", "no branch protection rule configured on default branch"))
            continue

        if protection is None:
            findings.append(Finding(repo_name, rule_id, description, standard,
                                     "FAIL", "not configured / unverifiable — no branch protection rule at all"))
            continue

        field = rule["field"]
        field_value = protection.get(field)

        if field_value is None:
            findings.append(Finding(repo_name, rule_id, description, standard,
                                     "FAIL", f"field '{field}' not returned — insufficient permission or not set"))
            continue

        if check == "is_true":
            ok = field_value is True
        elif check == "is_false":
            ok = field_value is False
        elif check == "min_value":
            ok = field_value >= rule["value"]
        else:
            raise ValueError(f"Unknown check type '{check}' in rule '{rule_id}'")

        status = "PASS" if ok else "FAIL"
        reason = f"{field}={field_value}"
        findings.append(Finding(repo_name, rule_id, description, standard, status, reason))

    return findings
