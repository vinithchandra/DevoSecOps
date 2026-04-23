-- Experiment 1: Security Layer Ablation Study
-- Measures marginal contribution of each security layer in detecting attack vectors

CREATE SCHEMA IF NOT EXISTS `research.experiment1_security_ablation`
  OPTIONS(
    description = "Security layer ablation study - 4x4 matrix of attack detection"
  );

-- Main table for all ablation trials
CREATE TABLE IF NOT EXISTS `research.experiment1_security_ablation.trials` (
  trial_id STRING NOT NULL,
  experiment STRING NOT NULL DEFAULT 'E1',
  attack_category STRING NOT NULL,  -- 'critical_cve', 'hardcoded_secret', 'privileged_pod', 'runtime_attack'
  layer_under_test STRING NOT NULL,  -- 'pre_commit', 'ci_trivy', 'opa_gatekeeper', 'falco'
  other_layers_active ARRAY<STRING> NOT NULL,
  detected BOOLEAN NOT NULL,
  detection_latency_seconds FLOAT64,
  false_positive BOOLEAN NOT NULL,
  raw_log STRING,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  environment STRING NOT NULL DEFAULT 'dev',
  metadata JSON
)
PARTITION BY TIMESTAMP(timestamp)
CLUSTER BY attack_category, layer_under_test
OPTIONS(
  description = "Individual ablation trial results - 64 trials total (4 layers x 4 attacks x 16 combinations)"
);

-- Summary statistics table (materialized view)
CREATE TABLE IF NOT EXISTS `research.experiment1_security_ablation.layer_effectiveness` (
  layer STRING NOT NULL,
  attack_category STRING NOT NULL,
  total_trials INT64 NOT NULL,
  detected_count INT64 NOT NULL,
  detection_rate FLOAT64 NOT NULL,
  false_positive_count INT64 NOT NULL,
  false_positive_rate FLOAT64 NOT NULL,
  avg_detection_latency_seconds FLOAT64,
  std_detection_latency_seconds FLOAT64,
  last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS(
  description = "Aggregated effectiveness metrics per layer and attack type"
);

-- Chi-squared test results
CREATE TABLE IF NOT EXISTS `research.experiment1_security_ablation.statistical_significance` (
  test_name STRING NOT NULL,
  chi_squared_value FLOAT64 NOT NULL,
  p_value FLOAT64 NOT NULL,
  degrees_of_freedom INT64 NOT NULL,
  is_significant BOOLEAN NOT NULL,
  interpretation STRING,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS(
  description = "Statistical test results for layer contribution significance"
);

-- Layer combination effectiveness
CREATE TABLE IF NOT EXISTS `research.experiment1_security_ablation.combination_effectiveness` (
  layers_active ARRAY<STRING> NOT NULL,
  attack_category STRING NOT NULL,
  detection_rate FLOAT64 NOT NULL,
  trial_count INT64 NOT NULL,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS(
  description = "Detection rates for different layer combinations"
);

-- Insert sample data structure (for testing)
INSERT INTO `research.experiment1_security_ablation.trials` (
  trial_id,
  attack_category,
  layer_under_test,
  other_layers_active,
  detected,
  detection_latency_seconds,
  false_positive,
  raw_log,
  environment
)
SELECT
  FORMAT('E1-%s-%s-%04d', attack, layer, ROW_NUMBER() OVER()) as trial_id,
  attack,
  layer,
  [] as other_layers_active,
  true as detected,
  4.2 as detection_latency_seconds,
  false as false_positive,
  'admission webhook denied: policy privileged-containers' as raw_log,
  'dev' as environment
FROM UNNEST(['critical_cve', 'hardcoded_secret', 'privileged_pod', 'runtime_attack']) as attack
CROSS JOIN UNNEST(['pre_commit', 'ci_trivy', 'opa_gatekeeper', 'falco']) as layer
LIMIT 0;  -- Empty insert, just schema validation
