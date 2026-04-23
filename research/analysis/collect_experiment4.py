"""Research data collection for Experiment 4: CI Gate Effectiveness."""
import os
import json
import uuid
from datetime import datetime, timezone
from google.cloud import bigquery

PROJECT_ID = os.environ.get("PROJECT_ID", "PROJECT_ID")
DATASET = "research.experiment4_ci_gate_effectiveness"

client = bigquery.Client(project=PROJECT_ID)

GATE_NAMES = [
    "pre_commit",
    "semgrep",
    "pip_audit",
    "checkov",
    "trivy_dependency",
    "trivy_image",
    "cosign",
]


def record_gate_execution(
    run_id: str,
    commit_sha: str,
    gate_name: str,
    duration_seconds: float,
    result: str,
    findings_count: int = 0,
    critical_count: int = 0,
    high_count: int = 0,
    suppressed_count: int = 0,
    introduced_by_commit: bool = False,
    developer_override: bool = False,
) -> str:
    """Record a single gate execution result."""
    execution_id = f"e4-{uuid.uuid4().hex[:8]}"

    row = {
        "execution_id": execution_id,
        "run_id": run_id,
        "commit_sha": commit_sha,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "gate_name": gate_name,
        "duration_seconds": duration_seconds,
        "result": result,
        "findings_count": findings_count,
        "critical_count": critical_count,
        "high_count": high_count,
        "suppressed_count": suppressed_count,
        "introduced_by_commit": introduced_by_commit,
        "developer_override": developer_override,
    }

    errors = client.insert_rows_json(f"{DATASET}.gate_executions", [row])
    if errors:
        raise RuntimeError(f"BigQuery insert failed: {errors}")

    return execution_id


def classify_finding(
    execution_id: str,
    gate_name: str,
    finding_id: str,
    classification: str,
    classifier: str,
    notes: str = "",
) -> str:
    """Classify a finding as true_positive, false_positive, or config_issue."""
    classification_id = f"e4c-{uuid.uuid4().hex[:8]}"

    row = {
        "classification_id": classification_id,
        "execution_id": execution_id,
        "gate_name": gate_name,
        "finding_id": finding_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "classification": classification,
        "classifier": classifier,
        "notes": notes,
    }

    errors = client.insert_rows_json(f"{DATASET}.finding_classification", [row])
    if errors:
        raise RuntimeError(f"BigQuery insert failed: {errors}")

    return classification_id


def compute_gate_effectiveness() -> list[dict]:
    """Compute per-gate precision and recall metrics."""
    query = f"""
    WITH classified AS (
      SELECT
        g.gate_name,
        g.findings_count,
        g.duration_seconds,
        g.suppressed_count,
        c.classification,
        COUNT(c.classification) as classification_count
      FROM `{DATASET}.gate_executions` g
      LEFT JOIN `{DATASET}.finding_classification` c
        ON g.execution_id = c.execution_id
      GROUP BY g.gate_name, g.findings_count, g.duration_seconds, g.suppressed_count, c.classification
    )
    SELECT
      gate_name,
      SUM(CASE WHEN classification = 'true_positive' THEN classification_count ELSE 0 END) as true_positives,
      SUM(CASE WHEN classification = 'false_positive' THEN classification_count ELSE 0 END) as false_positives,
      SUM(CASE WHEN classification = 'config_issue' THEN classification_count ELSE 0 END) as config_issues,
      AVG(duration_seconds) as avg_duration,
      AVG(suppressed_count) as avg_suppressions,
      COUNT(*) as total_executions
    FROM `{DATASET}.gate_executions`
    GROUP BY gate_name
    ORDER BY gate_name
    """

    query_job = client.query(query)
    return [dict(row) for row in query_job]


def compute_weekly_summary() -> list[dict]:
    """Compute weekly summary of CI gate effectiveness."""
    query = f"""
    SELECT
      DATE_TRUNC(TIMESTAMP(timestamp), WEEK) as week,
      gate_name,
      COUNT(*) as total_runs,
      SUM(CASE WHEN result = 'failure' THEN 1 ELSE 0 END) as failures,
      AVG(duration_seconds) as avg_duration,
      SUM(findings_count) as total_findings,
      SUM(critical_count) as total_critical,
      SUM(suppressed_count) as total_suppressions
    FROM `{DATASET}.gate_executions`
    GROUP BY week, gate_name
    ORDER BY week DESC, gate_name
    """

    query_job = client.query(query)
    return [dict(row) for row in query_job]


if __name__ == "__main__":
    print("Experiment 4: CI Gate Effectiveness")
    print("=" * 50)

    print("\nComputing gate effectiveness...")
    effectiveness = compute_gate_effectiveness()
    for row in effectiveness:
        print(f"  {row['gate_name']}:")
        print(f"    Executions: {row['total_executions']}")
        print(f"    Avg duration: {row['avg_duration']:.1f}s")
        print(f"    Avg suppressions: {row['avg_suppressions']:.1f}")

    print("\nComputing weekly summary...")
    weekly = compute_weekly_summary()
    for row in weekly[:7]:
        print(f"  Week {row['week']}: {row['gate_name']} - {row['total_runs']} runs, {row['failures']} failures")
