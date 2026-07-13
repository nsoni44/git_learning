import json
import unittest
from pathlib import Path

from org_audit.rules import evaluate_repo, load_rules

FIXTURES = Path(__file__).parent / "fixtures"
RULES_PATH = Path(__file__).parent.parent / "rules" / "baseline.yaml"


class TestRuleEvaluation(unittest.TestCase):
    def setUp(self):
        self.rules = load_rules(RULES_PATH)

    def _load_fixture(self, name):
        with open(FIXTURES / name) as f:
            return json.load(f)

    def test_compliant_repo_passes_all_rules(self):
        repo = self._load_fixture("repo_compliant.json")
        findings = evaluate_repo(repo, self.rules)
        failing = [f for f in findings if f.status == "FAIL"]
        self.assertEqual(failing, [], f"expected no failures, got: {failing}")
        self.assertEqual(len(findings), len(self.rules))

    def test_repo_with_no_branch_protection_fails_every_rule(self):
        repo = self._load_fixture("repo_noncompliant.json")
        findings = evaluate_repo(repo, self.rules)
        passing = [f for f in findings if f.status == "PASS"]
        self.assertEqual(passing, [], f"expected no passes, got: {passing}")
        self.assertEqual(len(findings), len(self.rules))

    def test_missing_field_is_treated_as_fail_not_skip(self):
        repo = {
            "name": "partial-repo",
            "isArchived": False,
            "defaultBranchRef": {
                "name": "main",
                "branchProtectionRule": {
                    "isAdminEnforced": True,
                    "allowsForcePushes": False,
                    "allowsDeletions": False,
                    "requiresApprovingReviews": True,
                    "requiredApprovingReviewCount": 1,
                    # requiresCommitSignatures omitted entirely, e.g. token lacks scope
                },
            },
        }
        findings = evaluate_repo(repo, self.rules)
        sig_finding = next(f for f in findings if f.rule_id == "requires_commit_signatures")
        self.assertEqual(sig_finding.status, "FAIL")
        self.assertIn("insufficient permission", sig_finding.reason)

    def test_min_approving_reviews_boundary(self):
        repo = self._load_fixture("repo_compliant.json")
        repo["defaultBranchRef"]["branchProtectionRule"]["requiredApprovingReviewCount"] = 0
        findings = evaluate_repo(repo, self.rules)
        review_finding = next(f for f in findings if f.rule_id == "min_approving_reviews")
        self.assertEqual(review_finding.status, "FAIL")


if __name__ == "__main__":
    unittest.main()
