-- BigQuery Dataset Setup Script
-- Run this first to create all datasets and tables for the research project

-- Create the research dataset if it doesn't exist
CREATE SCHEMA IF NOT EXISTS `research`
  OPTIONS(
    description = "Research data collection for DevSecOps multi-tenant SaaS platform",
    location = "US"
  );

-- Grant access to service accounts
-- Replace with actual service account emails
-- GRANT `roles/bigquery.dataEditor` ON SCHEMA `research` TO "serviceAccount:n8n-sa@PROJECT_ID.iam.gserviceaccount.com";
-- GRANT `roles/bigquery.dataViewer` ON SCHEMA `research` TO "serviceAccount:argocd-sa@PROJECT_ID.iam.gserviceaccount.com";

-- Create views for cross-experiment analysis
CREATE OR REPLACE VIEW `research.cross_experiment_summary` AS
SELECT
  'E1' as experiment_id,
  'Security Ablation' as experiment_name,
  COUNT(DISTINCT trial_id) as total_trials,
  MIN(timestamp) as first_trial,
  MAX(timestamp) as last_trial
FROM `research.experiment1_security_ablation.trials`

UNION ALL

SELECT
  'E2' as experiment_id,
  'Automation MTTR' as experiment_name,
  COUNT(DISTINCT trial_id) as total_trials,
  MIN(timestamp) as first_trial,
  MAX(timestamp) as last_trial
FROM `research.experiment2_automation_mttr.incident_trials`

UNION ALL

SELECT
  'E3' as experiment_id,
  'Chaos SLO Calibration' as experiment_name,
  COUNT(DISTINCT trial_id) as total_trials,
  MIN(timestamp) as first_trial,
  MAX(timestamp) as last_trial
FROM `research.experiment3_chaos_slo_calibration.chaos_trials`

UNION ALL

SELECT
  'E4' as experiment_id,
  'CI Gate Effectiveness' as experiment_name,
  COUNT(DISTINCT run_id) as total_trials,
  MIN(timestamp) as first_trial,
  MAX(timestamp) as last_trial
FROM `research.experiment4_ci_gate_effectiveness.gate_executions`

UNION ALL

SELECT
  'E5' as experiment_id,
  'Tenant Isolation' as experiment_name,
  COUNT(*) as total_trials,
  MIN(timestamp) as first_trial,
  MAX(timestamp) as last_trial
FROM `research.experiment5_tenant_isolation.performance_metrics`;

-- Create view for research publication readiness
CREATE OR REPLACE VIEW `research.publication_readiness` AS
SELECT
  experiment_id,
  experiment_name,
  total_trials,
  CASE
    WHEN experiment_id = 'E1' AND total_trials >= 64 THEN true
    WHEN experiment_id = 'E2' AND total_trials >= 16 THEN true
    WHEN experiment_id = 'E3' AND total_trials >= 50 THEN true
    WHEN experiment_id = 'E4' AND total_trials >= 200 THEN true
    WHEN experiment_id = 'E5' AND total_trials >= 1500 THEN true
    ELSE false
  END as meets_sample_size,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), first_trial, DAY) as data_collection_days,
  CASE
    WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), first_trial, DAY) >= 7 THEN true
    ELSE false
  END as has_baseline_week,
  last_trial as most_recent_data
FROM `research.cross_experiment_summary`;

-- Scheduled query for updating summary statistics
-- This would be set up as a scheduled query in BigQuery
-- Run daily to refresh aggregate tables
