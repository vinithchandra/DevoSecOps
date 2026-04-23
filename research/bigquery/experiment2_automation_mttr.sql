-- Experiment 2: Automation Impact on MTTR
-- Measures reduction in Mean Time To Resolve with n8n automation vs manual

CREATE SCHEMA IF NOT EXISTS `research.experiment2_automation_mttr`
  OPTIONS(
    description = "Automation impact on incident response - MTTR comparison"
  );

-- Incident response trials
CREATE TABLE IF NOT EXISTS `research.experiment2_automation_mttr.incident_trials` (
  trial_id STRING NOT NULL,
  experiment STRING NOT NULL DEFAULT 'E2',
  scenario_id STRING NOT NULL,  -- 'db_connection_pool_exhaustion', 'pod_oomkilled', etc.
  severity STRING NOT NULL,  -- 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
  mode STRING NOT NULL,  -- 'automated' or 'manual'
  alert_fired_at TIMESTAMP NOT NULL,
  first_human_notified_at TIMESTAMP NOT NULL,
  incident_ticket_created_at TIMESTAMP,
  context_richness_score INT64 NOT NULL,  -- 1-10 scale
  correct_root_cause_identified BOOLEAN NOT NULL,
  time_to_correct_rca_seconds FLOAT64,
  automated_action_taken STRING,  -- 'ArgoCD rollback triggered', etc.
  human_intervention_required BOOLEAN NOT NULL,
  mttt_seconds FLOAT64,  -- Mean Time To Detect
  mttr_seconds FLOAT64,  -- Mean Time To Resolve
  resolution_status STRING NOT NULL,  -- 'resolved', 'escalated', 'ongoing'
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  environment STRING NOT NULL DEFAULT 'dev',
  metadata JSON
)
PARTITION BY TIMESTAMP(timestamp)
CLUSTER BY scenario_id, mode
OPTIONS(
  description = "Individual incident response trials - 8 scenarios x 2 modes = 16+ trials"
);

-- Scenario definitions
CREATE TABLE IF NOT EXISTS `research.experiment2_automation_mttr.scenarios` (
  scenario_id STRING NOT NULL,
  scenario_name STRING NOT NULL,
  description STRING,
  expected_root_cause STRING,
  expected_automated_action STRING,
  severity STRING NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true
)
OPTIONS(
  description = "Definitions of synthetic incident scenarios"
);

-- MTTR summary statistics
CREATE TABLE IF NOT EXISTS `research.experiment2_automation_mttr.mttr_summary` (
  mode STRING NOT NULL,
  scenario_id STRING NOT NULL,
  trial_count INT64 NOT NULL,
  mttt_mean_seconds FLOAT64 NOT NULL,
  mttt_median_seconds FLOAT64 NOT NULL,
  mttt_p95_seconds FLOAT64 NOT NULL,
  mttr_mean_seconds FLOAT64 NOT NULL,
  mttr_median_seconds FLOAT64 NOT NULL,
  mttr_p95_seconds FLOAT64 NOT NULL,
  context_richness_mean FLOAT64 NOT NULL,
  correct_rca_rate FLOAT64 NOT NULL,
  human_intervention_rate FLOAT64 NOT NULL,
  last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS(
  description = "Aggregated MTTR metrics per mode and scenario"
);

-- Paired t-test results
CREATE TABLE IF NOT EXISTS `research.experiment2_automation_mttr.statistical_significance` (
  metric_name STRING NOT NULL,  -- 'mttt', 'mttr', 'context_richness'
  t_statistic FLOAT64 NOT NULL,
  p_value FLOAT64 NOT NULL,
  degrees_of_freedom INT64 NOT NULL,
  is_significant BOOLEAN NOT NULL,
  effect_size FLOAT64 NOT NULL,  -- Cohen's d
  interpretation STRING,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS(
  description = "Statistical test results for automated vs manual comparison"
);

-- Insert scenario definitions
INSERT INTO `research.experiment2_automation_mttr.scenarios` (scenario_id, scenario_name, description, expected_root_cause, expected_automated_action, severity)
VALUES
  ('slo_burn_rate', 'SLO Burn Rate Breach', 'Error rate spike caused by bad deployment', 'Bad code deployment', 'ArgoCD rollback', 'HIGH'),
  ('pod_oomkilled', 'Pod OOMKilled', 'Memory limit too low causing pod crashes', 'Insufficient memory limit', 'Increase memory limit', 'MEDIUM'),
  ('cert_expiry', 'Certificate Expiry Warning', 'TLS certificate approaching expiration', 'Certificate not renewed', 'Trigger cert-manager renewal', 'LOW'),
  ('cross_tenant_probe', 'Cross-Tenant Network Probe', 'Falco alert on cross-namespace connection attempt', 'Misconfigured NetworkPolicy', 'Block source pod', 'HIGH'),
  ('db_pool_exhaustion', 'DB Connection Pool Exhaustion', 'Database connection pool exhausted', 'Connection leak in application', 'Restart affected pods', 'HIGH'),
  ('node_cpu_saturation', 'Node CPU Saturation', 'HPA not scaling fast enough', 'CPU-intensive workload', 'Adjust HPA thresholds', 'MEDIUM'),
  ('image_pull_failure', 'Image Pull Failure', 'Artifact Registry authentication issue', 'Invalid credentials', 'Rotate service account key', 'HIGH'),
  ('deployment_stuck', 'Deployment Stuck Progressing', 'ArgoCD sync stuck in progressing state', 'Resource constraints', 'Check resource quotas', 'MEDIUM');
