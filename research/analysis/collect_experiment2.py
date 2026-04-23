"""Research data collection scripts for Experiment 2: Automation Impact on MTTR."""
import os
import uuid
from datetime import datetime, timezone
from google.cloud import bigquery

PROJECT_ID = os.environ.get("PROJECT_ID", "PROJECT_ID")
DATASET = "research.experiment2_automation_mttr"

client = bigquery.Client(project=PROJECT_ID)

SCENARIO_DEFINITIONS = [
    {
        "scenario_id": "slo_burn_rate",
        "name": "SLO Burn Rate Breach",
        "severity": "critical",
        "description": "Error rate spike from bad deploy",
        "expected_rca": "Bad deployment causing 5xx errors",
    },
    {
        "scenario_id": "pod_oom",
        "name": "Pod OOMKilled",
        "severity": "high",
        "description": "Memory limit too low, pod killed",
        "expected_rca": "Memory limit needs increase",
    },
    {
        "scenario_id": "cert_expiry",
        "name": "Certificate Expiry Warning",
        "severity": "medium",
        "description": "cert-manager notification of expiring cert",
        "expected_rca": "Certificate renewal failed",
    },
    {
        "scenario_id": "cross_tenant_probe",
        "name": "Cross-Tenant Network Probe",
        "severity": "critical",
        "description": "Falco alert for cross-namespace traffic",
        "expected_rca": "NetworkPolicy misconfiguration",
    },
    {
        "scenario_id": "db_pool_exhaustion",
        "name": "DB Connection Pool Exhaustion",
        "severity": "high",
        "description": "All DB connections consumed",
        "expected_rca": "Connection leak in application code",
    },
    {
        "scenario_id": "node_cpu_saturation",
        "name": "Node CPU Saturation",
        "severity": "high",
        "description": "HPA not scaling fast enough",
        "expected_rca": "HPA scaling delay + burst traffic",
    },
    {
        "scenario_id": "image_pull_failure",
        "name": "Image Pull Failure",
        "severity": "medium",
        "description": "Artifact Registry authentication issue",
        "expected_rca": "Workload Identity binding expired",
    },
    {
        "scenario_id": "deploy_stuck",
        "name": "Deployment Stuck Progressing",
        "severity": "medium",
        "description": "ArgoCD sync stuck in Progressing state",
        "expected_rca": "Readiness probe misconfigured",
    },
]


def insert_scenario_definitions():
    """Insert scenario definitions into BigQuery."""
    rows = []
    for s in SCENARIO_DEFINITIONS:
        rows.append({
            "scenario_id": s["scenario_id"],
            "name": s["name"],
            "severity": s["severity"],
            "description": s["description"],
            "expected_rca": s["expected_rca"],
        })

    errors = client.insert_rows_json(f"{DATASET}.scenario_definitions", rows)
    if errors:
        raise RuntimeError(f"BigQuery insert failed: {errors}")
    print(f"Inserted {len(rows)} scenario definitions")


def record_incident_trial(
    scenario_id: str,
    mode: str,
    alert_fired_at: str,
    first_human_notified_at: str = None,
    incident_ticket_created_at: str = None,
    context_richness_score: int = 0,
    correct_root_cause_identified: bool = False,
    time_to_correct_rca_seconds: float = 0.0,
    automated_action_taken: str = None,
) -> str:
    """Record a single incident trial result."""
    trial_id = f"e2-{uuid.uuid4().hex[:8]}"

    # Calculate MTTD and MTTR
    mttd_seconds = 0.0
    mttr_seconds = 0.0

    if first_human_notified_at:
        mttd_seconds = (datetime.fromisoformat(first_human_notified_at) -
                        datetime.fromisoformat(alert_fired_at)).total_seconds()

    if incident_ticket_created_at:
        mttr_seconds = (datetime.fromisoformat(incident_ticket_created_at) -
                        datetime.fromisoformat(alert_fired_at)).total_seconds()

    row = {
        "trial_id": trial_id,
        "scenario_id": scenario_id,
        "mode": mode,
        "alert_fired_at": alert_fired_at,
        "first_human_notified_at": first_human_notified_at,
        "incident_ticket_created_at": incident_ticket_created_at,
        "mttd_seconds": mttd_seconds,
        "mttr_seconds": mttr_seconds,
        "context_richness_score": context_richness_score,
        "correct_root_cause_identified": correct_root_cause_identified,
        "time_to_correct_rca_seconds": time_to_correct_rca_seconds,
        "automated_action_taken": automated_action_taken,
    }

    errors = client.insert_rows_json(f"{DATASET}.incident_trials", [row])
    if errors:
        raise RuntimeError(f"BigQuery insert failed: {errors}")

    return trial_id


def compute_mttr_summary() -> list[dict]:
    """Compute MTTR summary statistics by mode."""
    query = f"""
    SELECT
      mode,
      COUNT(*) as total_trials,
      AVG(mttr_seconds) as mean_mttr,
      APPROX_QUANTILES(mttr_seconds, 100)[OFFSET(50)] as median_mttr,
      APPROX_QUANTILES(mttr_seconds, 100)[OFFSET(95)] as p95_mttr,
      AVG(mttd_seconds) as mean_mttd,
      AVG(context_richness_score) as mean_context_richness,
      SUM(CASE WHEN correct_root_cause_identified THEN 1 ELSE 0 END) / COUNT(*) as correct_rca_rate
    FROM `{DATASET}.incident_trials`
    GROUP BY mode
    """

    query_job = client.query(query)
    return [dict(row) for row in query_job]


def run_paired_t_test() -> dict:
    """Run paired t-test comparing automated vs manual MTTR."""
    from scipy import stats
    import numpy as np

    query = f"""
    SELECT
      scenario_id,
      mode,
      mttr_seconds
    FROM `{DATASET}.incident_trials`
    ORDER BY scenario_id, mode
    """

    query_job = client.query(query)
    rows = list(query_job)

    manual = [r["mttr_seconds"] for r in rows if r["mode"] == "manual"]
    automated = [r["mttr_seconds"] for r in rows if r["mode"] == "automated"]

    if len(manual) < 2 or len(automated) < 2:
        return {"error": "Insufficient data for paired t-test"}

    t_stat, p_value = stats.ttest_rel(manual, automated)

    # Cohen's d
    diff = np.array(manual) - np.array(automated)
    cohens_d = float(np.mean(diff) / np.std(diff, ddof=1))

    result = {
        "test": "paired_t_test",
        "t_statistic": float(t_stat),
        "p_value": float(p_value),
        "significant_at_005": float(p_value) < 0.05,
        "cohens_d": cohens_d,
        "manual_mean_mttr": float(np.mean(manual)),
        "automated_mean_mttr": float(np.mean(automated)),
        "mttr_reduction_pct": float((1 - np.mean(automated) / np.mean(manual)) * 100),
    }

    # Write to statistical_significance table
    stat_row = {
        "test_name": "paired_t_test_mttr",
        "statistic": result["t_statistic"],
        "p_value": result["p_value"],
        "effect_size_cohens_d": result["cohens_d"],
        "significant": result["significant_at_005"],
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    errors = client.insert_rows_json(f"{DATASET}.statistical_significance", [stat_row])
    if errors:
        print(f"Warning: stat insert failed: {errors}")

    return result


if __name__ == "__main__":
    print("Experiment 2: Automation Impact on MTTR")
    print("=" * 50)

    # Insert scenario definitions
    print("\nInserting scenario definitions...")
    insert_scenario_definitions()

    # Compute summary
    print("\nComputing MTTR summary...")
    summary = compute_mttr_summary()
    for row in summary:
        print(f"  Mode: {row['mode']}")
        print(f"    Mean MTTR: {row['mean_mttr']:.1f}s")
        print(f"    Median MTTR: {row['median_mttr']:.1f}s")
        print(f"    Context Richness: {row['mean_context_richness']:.1f}/10")
        print(f"    Correct RCA Rate: {row['correct_rca_rate']:.1%}")

    # Run statistical test
    print("\nRunning paired t-test...")
    stats = run_paired_t_test()
    if "error" not in stats:
        print(f"  t = {stats['t_statistic']:.2f}")
        print(f"  p = {stats['p_value']:.4f}")
        print(f"  Cohen's d = {stats['cohens_d']:.2f}")
        print(f"  MTTR reduction = {stats['mttr_reduction_pct']:.1f}%")
    else:
        print(f"  {stats['error']}")
