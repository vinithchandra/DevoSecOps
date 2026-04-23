-- Experiment 4: CI Pipeline Gate Effectiveness and Cost
-- Measures true/false positive rates and cost of each security gate

CREATE SCHEMA IF NOT EXISTS `research.experiment4_ci_gate_effectiveness`
  OPTIONS(
    description = "CI pipeline gate effectiveness - precision, recall, and cost analysis"
  );

-- CI gate execution results
CREATE TABLE IF NOT EXISTS `research.experiment4_ci_gate_effectiveness.gate_executions` (
  run_id STRING NOT NULL,
  commit_sha STRING NOT NULL,
  gate_name STRING NOT NULL,  -- 'pre_commit', 'semgrep', 'pip_audit', 'checkov', 'trivy_dep', 'trivy_image', 'cosign'
  duration_seconds FLOAT64 NOT NULL,
  result STRING NOT NULL,  -- 'pass', 'fail', 'error'
  findings_count INT64 NOT NULL,
  critical_count INT64 NOT NULL,
  high_count INT64 NOT NULL,
  medium_count INT64 NOT NULL,
  low_count INT64 NOT NULL,
  suppressed_count INT64 NOT NULL,
  introduced_by_commit BOOLEAN NOT NULL,
  developer_override BOOLEAN NOT NULL,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  branch STRING NOT NULL,
  environment STRING NOT NULL DEFAULT 'dev',
  metadata JSON
)
PARTITION BY TIMESTAMP(timestamp)
CLUSTER BY gate_name, result
OPTIONS(
  description = "Individual CI gate execution results - continuous over 8 weeks"
);

-- Gate effectiveness metrics
CREATE TABLE IF NOT EXISTS `research.experiment4_ci_gate_effectiveness.gate_effectiveness` (
  gate_name STRING NOT NULL,
  total_executions INT64 NOT NULL,
  pass_count INT64 NOT NULL,
  fail_count INT64 NOT NULL,
  error_count INT64 NOT NULL,
  total_findings INT64 NOT NULL,
  true_positive_count INT64 NOT NULL,
  false_positive_count INT64 NOT NULL,
  configuration_issue_count INT64 NOT NULL,
  precision FLOAT64 NOT NULL,  -- TP / (TP + FP)
  recall FLOAT64 NOT NULL,  -- TP / (TP + FN) - if we have ground truth
  avg_duration_seconds FLOAT64 NOT NULL,
  std_duration_seconds FLOAT64 NOT NULL,
  avg_findings_per_run FLOAT64 NOT NULL,
  suppression_rate FLOAT64 NOT NULL,  -- suppressed / total findings
  developer_override_rate FLOAT64 NOT NULL,
  last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS(
  description = "Aggregated effectiveness metrics per gate"
);

-- Pipeline cost analysis
CREATE TABLE IF NOT EXISTS `research.experiment4_ci_gate_effectiveness.pipeline_cost` (
  run_id STRING NOT NULL,
  commit_sha STRING NOT NULL,
  total_duration_seconds FLOAT64 NOT NULL,
  security_gates_duration_seconds FLOAT64 NOT NULL,
  build_test_duration_seconds FLOAT64 NOT NULL,
  other_duration_seconds FLOAT64 NOT NULL,
  security_gates_overhead_pct FLOAT64 NOT NULL,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  branch STRING NOT NULL
)
PARTITION BY TIMESTAMP(timestamp)
CLUSTER BY branch
OPTIONS(
  description = "Pipeline duration and cost breakdown per run"
);

-- Finding classification (manual review)
CREATE TABLE IF NOT EXISTS `research.experiment4_ci_gate_effectiveness.finding_classification` (
  finding_id STRING NOT NULL,
  run_id STRING NOT NULL,
  gate_name STRING NOT NULL,
  finding_type STRING NOT NULL,  -- 'critical', 'high', 'medium', 'low'
  classification STRING NOT NULL,  -- 'true_positive', 'false_positive', 'configuration_issue'
  actual_severity STRING,  -- 'critical', 'high', 'medium', 'low', 'none'
  notes STRING,
  classified_by STRING NOT NULL,
  classification_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS(
  description = "Manual classification of findings for precision/recall calculation"
);

-- Developer friction metrics
CREATE TABLE IF NOT EXISTS `research.experiment4_ci_gate_effectiveness.developer_friction` (
  commit_sha STRING NOT NULL,
  suppression_type STRING NOT NULL,  -- 'trivyignore', 'nosec', 'noqa', etc.
  gate_affected STRING NOT NULL,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  developer STRING NOT NULL
)
PARTITION BY TIMESTAMP(timestamp)
CLUSTER BY suppression_type, gate_affected
OPTIONS(
  description = "Developer suppression events as proxy for false-positive friction"
);

-- Weekly summary
CREATE TABLE IF NOT EXISTS `research.experiment4_ci_gate_effectiveness.weekly_summary` (
  week_start_date DATE NOT NULL,
  week_end_date DATE NOT NULL,
  total_runs INT64 NOT NULL,
  total_findings INT64 NOT NULL,
  avg_pipeline_duration_seconds FLOAT64 NOT NULL,
  false_positives_per_week INT64 NOT NULL,
  true_positives_per_week INT64 NOT NULL,
  developer_suppressions INT64 NOT NULL,
  last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS(
  description = "Weekly aggregated metrics for trend analysis"
);
