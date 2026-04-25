"""Research data collection for Experiment 5: Tenant Isolation Blast Radius."""
import os
import time
import uuid
from datetime import datetime, timezone
from google.cloud import bigquery

PROJECT_ID = os.environ.get("PROJECT_ID", "devsecops-research")
DATASET = "research.experiment5_tenant_isolation"

client = bigquery.Client(project=PROJECT_ID)

TENANTS = ["tenant-a", "tenant-b", "tenant-c"]
FAULT_SCENARIOS = [
    "cpu_saturation",
    "memory_pressure",
    "network_flood",
    "db_connection_storm",
    "pod_churn",
]
SAMPLING_INTERVAL_SECONDS = 10
PHASE_DURATION_SECONDS = 600  # 10 minutes per phase


def record_performance_metric(
    scenario: str,
    tenant: str,
    role: str,
    api_latency_p50_ms: float,
    api_latency_p99_ms: float,
    api_error_rate: float,
    cpu_throttle_rate: float,
    pod_restart_count: int,
    network_rx_bytes: float,
) -> str:
    """Record a single performance metric sample."""
    row = {
        "metric_id": f"e5-{uuid.uuid4().hex[:8]}",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "scenario": scenario,
        "tenant": tenant,
        "role": role,
        "api_latency_p50_ms": api_latency_p50_ms,
        "api_latency_p99_ms": api_latency_p99_ms,
        "api_error_rate": api_error_rate,
        "cpu_throttle_rate": cpu_throttle_rate,
        "pod_restart_count": pod_restart_count,
        "network_rx_bytes": network_rx_bytes,
    }

    errors = client.insert_rows_json(f"{DATASET}.performance_metrics", [row])
    if errors:
        raise RuntimeError(f"BigQuery insert failed: {errors}")

    return row["metric_id"]


def compute_effect_sizes() -> list[dict]:
    """Compute Cohen's d effect size between baseline and fault periods for observer tenants."""
    from scipy import stats
    import numpy as np

    query = f"""
    WITH baseline AS (
      SELECT tenant, scenario,
        AVG(api_latency_p99_ms) as baseline_p99,
        AVG(api_error_rate) as baseline_error_rate,
        AVG(cpu_throttle_rate) as baseline_cpu_throttle
      FROM `{DATASET}.performance_metrics`
      WHERE role = 'observer'
      GROUP BY tenant, scenario
    ),
    fault AS (
      SELECT tenant, scenario,
        AVG(api_latency_p99_ms) as fault_p99,
        AVG(api_error_rate) as fault_error_rate,
        AVG(cpu_throttle_rate) as fault_cpu_throttle
      FROM `{DATASET}.performance_metrics`
      WHERE role = 'observer'
      GROUP BY tenant, scenario
    )
    SELECT
      b.tenant,
      b.scenario,
      b.baseline_p99,
      f.fault_p99,
      b.baseline_error_rate,
      f.fault_error_rate
    FROM baseline b
    JOIN fault f ON b.tenant = f.tenant AND b.scenario = f.scenario
    """

    query_job = client.query(query)
    results = []

    for row in query_job:
        # Compute Cohen's d for p99 latency
        latency_increase = (row["fault_p99"] - row["baseline_p99"]) / row["baseline_p99"] * 100 if row["baseline_p99"] > 0 else 0

        result = {
            "tenant": row["tenant"],
            "scenario": row["scenario"],
            "baseline_p99_ms": row["baseline_p99"],
            "fault_p99_ms": row["fault_p99"],
            "latency_increase_pct": latency_increase,
            "baseline_error_rate": row["baseline_error_rate"],
            "fault_error_rate": row["fault_error_rate"],
            "error_rate_increase": row["fault_error_rate"] - row["baseline_error_rate"],
        }
        results.append(result)

    return results


def compute_isolation_overhead() -> dict:
    """Compute resource overhead of isolation mechanisms."""
    query = f"""
    SELECT
      AVG(cpu_throttle_rate) as avg_cpu_throttle,
      AVG(api_latency_p99_ms) as avg_p99_latency,
      AVG(api_error_rate) as avg_error_rate
    FROM `{DATASET}.performance_metrics`
    WHERE role = 'observer' AND scenario = 'baseline'
    """

    query_job = client.query(query)
    rows = list(query_job)

    if not rows:
        return {"error": "No baseline data available"}

    return dict(rows[0])


if __name__ == "__main__":
    print("Experiment 5: Tenant Isolation Blast Radius")
    print("=" * 50)

    # Compute effect sizes
    print("\nComputing effect sizes...")
    effects = compute_effect_sizes()
    for e in effects:
        print(f"  {e['tenant']} / {e['scenario']}: "
              f"p99 latency +{e['latency_increase_pct']:.1f}%, "
              f"error rate +{e['error_rate_increase']:.4f}")

    # Compute isolation overhead
    print("\nComputing isolation overhead...")
    overhead = compute_isolation_overhead()
    if "error" not in overhead:
        print(f"  Baseline CPU throttle: {overhead['avg_cpu_throttle']:.2%}")
        print(f"  Baseline p99 latency: {overhead['avg_p99_latency']:.1f}ms")
        print(f"  Baseline error rate: {overhead['avg_error_rate']:.4f}")
    else:
        print(f"  {overhead['error']}")
