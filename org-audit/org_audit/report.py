"""Console table + JSON rendering for findings."""
import json
from dataclasses import asdict


def to_table(findings) -> str:
    if not findings:
        return "(no findings)"

    rows = [("REPO", "RULE", "STATUS", "REASON")]
    rows += [(f.repo, f.rule_id, f.status, f.reason) for f in findings]
    widths = [max(len(str(row[i])) for row in rows) for i in range(4)]

    lines = []
    for i, row in enumerate(rows):
        line = " | ".join(str(cell).ljust(widths[j]) for j, cell in enumerate(row))
        lines.append(line)
        if i == 0:
            lines.append("-+-".join("-" * w for w in widths))

    fail_count = sum(1 for f in findings if f.status == "FAIL")
    lines.append("")
    lines.append(f"{len(findings)} checks run, {fail_count} failing, {len(findings) - fail_count} passing")
    return "\n".join(lines)


def to_json(findings) -> str:
    return json.dumps([asdict(f) for f in findings], indent=2)
