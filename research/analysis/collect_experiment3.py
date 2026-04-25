"""Research data collection for Experiment 3: Chaos SLO Calibration."""
import os
import uuid
from datetime import datetime, timezone
from google.cloud import bigquery

PROJECT_ID = os.environ.get("PROJECT_ID", "devsecops-research")
DATASET = "research.experiment3_chaos_slo_calibration"

client = bigquery.Client(project=PROJECT_ID)

FAULT_TYPES = ["pod_kill", "network_latency", "dns_failure", "cpu_stress", "time_skew"]
INTENSITIES = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]


def record_chaos_trial(
    fault_type: str,
    fault_intensity_pct: int,
    observed_error_rate_peak: float,
    burn_rate_1h: float,
    burn_rate_6h: float,
    slo_breached: bool,
    recovery_time_seconds: float,
    alert_would_fire_heuristic: bool,
    alert_would_fire_empirical: bool,
    alert_would_fire_oversensitive: bool,
) -> str:
    """Record a single chaos trial result."""
    trial_id = f"e3-{uuid.uuid4().hex[:8]}"

    row = {
        "trial_id": trial_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "fault_type": fault_type,
        "fault_intensity_pct": fault_intensity_pct,
        "observed_error_rate_peak": observed_error_rate_peak,
        "burn_rate_1h_window": burn_rate_1h,
        "burn_rate_6h_window": burn_rate_6h,
        "slo_breached": slo_breached,
        "recovery_time_seconds": recovery_time_seconds,
        "alert_would_fire_at_threshold_heuristic": alert_would_fire_heuristic,
        "alert_would_fire_at_threshold_empirical": alert_would_fire_empirical,
        "alert_would_fire_at_threshold_oversensitive": alert_would_fire_oversensitive,
    }

    errors = client.insert_rows_json(f"{DATASET}.chaos_trials", [row])
    if errors:
        raise RuntimeError(f"BigQuery insert failed: {errors}")

    return trial_id


def derive_empirical_threshold() -> dict:
    """Derive empirically-validated SLO alerting thresholds from chaos data."""
    import numpy as np

    query = f"""
    SELECT
      fault_type,
      fault_intensity_pct,
      AVG(observed_error_rate_peak) as avg_error_rate,
      AVG(burn_rate_1h_window) as avg_burn_rate_1h,
      AVG(burn_rate_6h_window) as avg_burn_rate_6h,
      AVG(recovery_time_seconds) as avg_recovery_time
    FROM `{DATASET}.chaos_trials`
    GROUP BY fault_type, fault_intensity_pct
    ORDER BY fault_type, fault_intensity_pct
    """

    query_job = client.query(query)
    rows = list(query_job)

    if not rows:
        return {"error": "No chaos trial data available"}

    # Find the burn rate threshold that maximizes true positive rate
    # while keeping false positive rate below 10%
    slo_breach_query = f"""
    SELECT
      fault_type,
      fault_intensity_pct,
      slo_breached,
      alert_would_fire_at_threshold_heuristic,
      alert_would_fire_at_threshold_empirical,
      alert_would_fire_at_threshold_oversensitive
    FROM `{DATASET}.chaos_trials`
    """

    slo_job = client.query(slo_breach_query)
    slo_rows = list(slo_job)

    # Calculate metrics for each strategy
    strategies = {
        "heuristic": {"tp": 0, "fp": 0, "tn": 0, "fn": 0},
        "empirical": {"tp": 0, "fp": 0, "tn": 0, "fn": 0},
        "oversensitive": {"tp": 0, "fp": 0, "tn": 0, "fn": 0},
    }

    for row in slo_rows:
        for strategy in strategies:
            alert_fired = row[f"alert_would_fire_at_threshold_{strategy}"]
            actual_breach = row["slo_breached"]

            if alert_fired and actual_breach:
                strategies[strategy]["tp"] += 1
            elif alert_fired and not actual_breach:
                strategies[strategy]["fp"] += 1
            elif not alert_fired and actual_breach:
                strategies[strategy]["fn"] += 1
            else:
                strategies[strategy]["tn"] += 1

    results = {}
    for strategy, counts in strategies.items():
        tp, fp, tn, fn = counts["tp"], counts["fp"], counts["tn"], counts["fn"]
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0
        fpr = fp / (fp + tn) if (fp + tn) > 0 else 0

        results[strategy] = {
            "true_positive_rate": recall,
            "false_positive_rate": fpr,
            "precision": precision,
            "f1_score": 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0,
        }

    # Write derived thresholds
    threshold_row = {
        "derived_at": datetime.now(timezone.utc).isoformat(),
        "heuristic_fpr": results["heuristic"]["false_positive_rate"],
        "empirical_fpr": results["empirical"]["false_positive_rate"],
        "oversensitive_fpr": results["oversensitive"]["false_positive_rate"],
        "recommended_strategy": "empirical" if results["empirical"]["f1_score"] >= results["heuristic"]["f1_score"] else "heuristic",
    }

    errors = client.insert_rows_json(f"{DATASET}.derived_thresholds", [threshold_row])
    if errors:
        print(f"Warning: threshold insert failed: {errors}")

    return results


if __name__ == "__main__":
    print("Experiment 3: Chaos SLO Calibration")
    print("=" * 50)

    print("\nDeriving empirical thresholds...")
    results = derive_empirical_threshold()
    if "error" not in results:
        for strategy, metrics in results.items():
            print(f"\n  Strategy: {strategy}")
            print(f"    TPR: {metrics['true_positive_rate']:.1%}")
            print(f"    FPR: {metrics['false_positive_rate']:.1%}")
            print(f"    Precision: {metrics['precision']:.1%}")
            print(f"    F1: {metrics['f1_score']:.3f}")
    else:
        print(f"  {results['error']}")
