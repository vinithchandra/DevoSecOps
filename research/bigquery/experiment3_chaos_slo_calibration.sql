-- Experiment 3: Chaos Engineering for SLO Threshold Calibration
-- Derives empirically-validated SLO alerting thresholds from chaos experiments

CREATE SCHEMA IF NOT EXISTS `research.experiment3_chaos_slo_calibration`
  OPTIONS(
    description = "Chaos engineering for SLO threshold calibration"
  );

-- Chaos experiment trials
CREATE TABLE IF NOT EXISTS `research.experiment3_chaos_slo_calibration.chaos_trials` (
  trial_id STRING NOT NULL,
  experiment STRING NOT NULL DEFAULT 'E3',
  fault_type STRING NOT NULL,  -- 'pod_kill', 'network_latency', 'dns_failure', 'cpu_stress', 'time_skew'
  fault_intensity_pct INT64 NOT NULL,  -- 10, 20, 30, ..., 100
  duration_seconds INT64 NOT NULL,
  observed_error_rate_peak FLOAT64 NOT NULL,
  observed_error_rate_mean FLOAT64 NOT NULL,
  burn_rate_1h_window FLOAT64 NOT NULL,
  burn_rate_6h_window FLOAT64 NOT NULL,
  slo_breached BOOLEAN NOT NULL,
  recovery_time_seconds FLOAT64 NOT NULL,
  hpa_scaled_at_seconds FLOAT64,
  alert_fired BOOLEAN NOT NULL,
  alert_would_fire_at_threshold_1x BOOLEAN NOT NULL,
  alert_would_fire_at_threshold_2x BOOLEAN NOT NULL,
  alert_would_fire_at_threshold_5x BOOLEAN NOT NULL,
  alert_would_fire_at_threshold_10x BOOLEAN NOT NULL,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  environment STRING NOT NULL DEFAULT 'dev',
  metadata JSON
)
PARTITION BY TIMESTAMP(timestamp)
CLUSTER BY fault_type, fault_intensity_pct
OPTIONS(
  description = "Individual chaos experiment trials - 50 trials (10 intensities x 5 runs)"
);

-- Dose-response curve data
CREATE TABLE IF NOT EXISTS `research.experiment3_chaos_slo_calibration.dose_response` (
  fault_type STRING NOT NULL,
  fault_intensity_pct INT64 NOT NULL,
  trial_count INT64 NOT NULL,
  avg_error_rate_peak FLOAT64 NOT NULL,
  avg_error_rate_mean FLOAT64 NOT NULL,
  avg_burn_rate_1h FLOAT64 NOT NULL,
  avg_burn_rate_6h FLOAT64 NOT NULL,
  slo_breach_rate FLOAT64 NOT NULL,
  avg_recovery_time_seconds FLOAT64 NOT NULL,
  std_recovery_time_seconds FLOAT64 NOT NULL,
  last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS(
  description = "Aggregated dose-response data per fault intensity"
);

-- Threshold comparison results
CREATE TABLE IF NOT EXISTS `research.experiment3_chaos_slo_calibration.threshold_comparison` (
  threshold_strategy STRING NOT NULL,  -- 'heuristic', 'empirical', 'over_sensitive'
  burn_rate_threshold FLOAT64 NOT NULL,
  true_positive_count INT64 NOT NULL,
  false_positive_count INT64 NOT NULL,
  false_negative_count INT64 NOT NULL,
  true_positive_rate FLOAT64 NOT NULL,
  false_positive_rate FLOAT64 NOT NULL,
  total_trials INT64 NOT NULL,
  last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS(
  description = "Comparison of different threshold strategies"
);

-- Empirically derived thresholds
CREATE TABLE IF NOT EXISTS `research.experiment3_chaos_slo_calibration.derived_thresholds` (
  metric_name STRING NOT NULL,
  window_type STRING NOT NULL,  -- '1h', '6h'
  recommended_threshold FLOAT64 NOT NULL,
  confidence_level FLOAT64 NOT NULL,  -- 0.95 for 95% confidence
  false_positive_rate_at_threshold FLOAT64 NOT NULL,
  true_positive_rate_at_threshold FLOAT64 NOT NULL,
  derivation_method STRING NOT NULL,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS(
  description = "Empirically derived SLO alerting thresholds"
);

-- Real fault injection results (Phase B)
CREATE TABLE IF NOT EXISTS `research.experiment3_chaos_slo_calibration.real_fault_injection` (
  fault_id STRING NOT NULL,
  fault_type STRING NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  threshold_used STRING NOT NULL,
  alert_fired BOOLEAN NOT NULL,
  was_real_problem BOOLEAN NOT NULL,
  classification STRING NOT NULL,  -- 'true_positive', 'false_positive', 'false_negative'
  time_to_alert_seconds FLOAT64,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY TIMESTAMP(timestamp)
CLUSTER BY threshold_used, classification
OPTIONS(
  description = "Real fault injection results for threshold validation"
);
