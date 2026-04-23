# Experiment 3: Chaos Engineering for SLO Threshold Calibration

## Research Question

Can chaos experiment results be used to empirically derive SLO alerting thresholds, and do thresholds derived this way produce fewer false positives than heuristically chosen ones?

## Why This Is Novel

Every paper on SLO alerting (including Google's SRE workbook) says "set your burn rate window empirically" but none actually shows how to do it with data. This experiment closes that gap.

## Experimental Design

### Phase A: Calibration Runs

Run Chaos Mesh experiments at 10 different fault intensities (10%, 20%, ..., 100% of pods killed). For each intensity, record:
- Actual error rate (peak and mean)
- Burn rate over 1h and 6h windows
- Whether SLO was breached
- Recovery time
- Whether alert fired at various thresholds

This gives a dose-response curve: fault intensity → observed burn rate.

Run each intensity level 5 times (50 trials total) to get a distribution, not just a point estimate.

### Data Collection Schema

Each trial logs to BigQuery table `research.experiment3_chaos_slo_calibration.chaos_trials`:

```json
{
  "trial_id": "chaos_20pct_pods_killed_run3",
  "fault_type": "pod_kill",
  "fault_intensity_pct": 20,
  "duration_seconds": 300,
  "observed_error_rate_peak": 0.023,
  "observed_error_rate_mean": 0.008,
  "burn_rate_1h_window": 1.4,
  "burn_rate_6h_window": 0.9,
  "slo_breached": false,
  "recovery_time_seconds": 87,
  "hpa_scaled_at_seconds": 45,
  "alert_fired": false,
  "alert_would_fire_at_threshold_2x": true,
  "alert_would_fire_at_threshold_5x": false,
  "alert_would_fire_at_threshold_10x": false
}
```

### Phase B: Threshold Comparison

Once we have empirical data, derive thresholds (burn rate at which 90% of chaos-induced failures would trigger while 5-minute transient spikes would not).

Compare three threshold strategies:
- **H**: Heuristic (Google's 2× and 10× from SRE workbook)
- **E**: Empirically derived from chaos data
- **O**: Over-sensitive (1× burn rate)

Inject 20 real fault scenarios across 4 weeks and record:
- True positives (real problem, alert fired)
- False positives (transient spike, alert fired unnecessarily)
- False negatives (real problem, no alert)

### Statistical Analysis

- **Dose-response curve**: Fit curve to fault intensity vs burn rate data
- **Threshold derivation**: Find burn rate that maximizes true positive rate while minimizing false positive rate
- **Comparison**: Compare false positive rates across H, E, O strategies using chi-squared test

### Expected Paper Claim

> "Empirically calibrated thresholds derived from chaos experiments reduced false positive rate from 31% (heuristic) to 8% while maintaining 100% true positive rate, demonstrating that chaos engineering can serve as a principled method for SLO threshold derivation rather than a post-hoc validation tool."

## Implementation Steps

1. **Week 3**: Set up Chaos Mesh, define fault types
2. **Week 4**: Run calibration trials (10 intensities × 5 runs = 50 trials)
3. **Week 5**: Analyze dose-response data, derive empirical thresholds
4. **Week 6-8**: Run real fault injection with all threshold strategies
5. **Week 9**: Statistical analysis, write results section

## Scripts

- `chaos_pod_kill.yaml` - Chaos Mesh experiment for pod kill
- `chaos_network_latency.yaml` - Chaos Mesh experiment for network latency
- `run_calibration_trials.sh` - Orchestrates calibration phase
- `derive_thresholds.py` - Analyzes calibration data, derives thresholds
- `run_validation_trials.sh` - Runs validation phase with all strategies
- `analyze_thresholds.py` - Statistical analysis and visualization

## Chaos Mesh Experiments

1. **PodChaos**: Kill 10%-100% of worker pods
2. **NetworkChaos**: Add 100ms-1000ms latency to API traffic
3. **DNSChaos**: Block DNS resolution for DB
4. **StressChaos**: CPU stress on tenant nodes
5. **TimeChaos**: Clock skew ±30s

## Data Quality Checks

- Ensure all 50 calibration trials completed (10 intensities × 5 runs)
- Verify burn rate calculations use correct window sizes
- Check that recovery time includes HPA scaling time
- Validate threshold derivation uses 90% confidence interval

## Threats to Validity

- Chaos experiments may not reflect real failure modes
- Sample size (50 trials) may be insufficient for rare events
- Fault intensities may not cover edge cases
- Address in paper: empirical derivation is better than heuristic even with limitations
