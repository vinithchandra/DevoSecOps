-- Experiment 5: Tenant Isolation Blast Radius Measurement
-- Quantifies performance impact of resource-exhausting tenants on co-located tenants

CREATE SCHEMA IF NOT EXISTS `research.experiment5_tenant_isolation`
  OPTIONS(
    description = "Tenant isolation blast radius - multi-tenancy performance impact"
  );

-- Tenant performance metrics during fault injection
CREATE TABLE IF NOT EXISTS `research.experiment5_tenant_isolation.performance_metrics` (
  scenario STRING NOT NULL,  -- 'cpu_saturation', 'memory_pressure', 'network_flood', 'db_storm', 'pod_churn'
  tenant STRING NOT NULL,  -- 'tenant-a', 'tenant-b', 'tenant-c'
  role STRING NOT NULL,  -- 'noisy_neighbour' or 'observer'
  timestamp TIMESTAMP NOT NULL,
  api_latency_p50_ms FLOAT64,
  api_latency_p99_ms FLOAT64,
  api_error_rate FLOAT64,
  cpu_throttle_rate FLOAT64,
  pod_restart_count INT64,
  network_rx_bytes INT64,
  network_tx_bytes INT64,
  db_query_latency_p99_ms FLOAT64,
  memory_usage_bytes INT64,
  experiment_phase STRING NOT NULL,  -- 'baseline', 'fault', 'recovery'
  environment STRING NOT NULL DEFAULT 'dev'
)
PARTITION BY TIMESTAMP(timestamp)
CLUSTER BY scenario, tenant, experiment_phase
OPTIONS(
  description = "High-frequency (10s) performance metrics during fault scenarios"
);

-- Fault injection events
CREATE TABLE IF NOT EXISTS `research.experiment5_tenant_isolation.fault_events` (
  fault_id STRING NOT NULL,
  scenario STRING NOT NULL,
  noisy_tenant STRING NOT NULL,
  fault_start TIMESTAMP NOT NULL,
  fault_end TIMESTAMP NOT NULL,
  fault_parameters JSON,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  environment STRING NOT NULL DEFAULT 'dev'
)
PARTITION BY TIMESTAMP(timestamp)
CLUSTER BY scenario
OPTIONS(
  description = "Fault injection event records"
);

-- Blast radius analysis results
CREATE TABLE IF NOT EXISTS `research.experiment5_tenant_isolation.blast_radius_analysis` (
  scenario STRING NOT NULL,
  observer_tenant STRING NOT NULL,
  baseline_mean_p99_ms FLOAT64 NOT NULL,
  fault_mean_p99_ms FLOAT64 NOT NULL,
  recovery_mean_p99_ms FLOAT64 NOT NULL,
  max_p99_increase_ms FLOAT64 NOT NULL,
  max_p99_increase_pct FLOAT64 NOT NULL,
  baseline_error_rate FLOAT64 NOT NULL,
  fault_error_rate FLOAT64 NOT NULL,
  error_rate_increase FLOAT64 NOT NULL,
  effect_size_cohens_d FLOAT64 NOT NULL,
  is_statistically_significant BOOLEAN NOT NULL,
  p_value FLOAT64,
  observations_during_fault INT64 NOT NULL,
  last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS(
  description = "Statistical analysis of blast radius per scenario and observer tenant"
);

-- Isolation overhead measurement
CREATE TABLE IF NOT EXISTS `research.experiment5_tenant_isolation.isolation_overhead` (
  component STRING NOT NULL,  -- 'network_policy', 'opa_webhook', 'falco_ebpf', etc.
  cpu_usage_percent FLOAT64 NOT NULL,
  memory_usage_bytes FLOAT64 NOT NULL,
  latency_impact_ms FLOAT64 NOT NULL,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  environment STRING NOT NULL DEFAULT 'dev'
)
PARTITION BY TIMESTAMP(timestamp)
CLUSTER BY component
OPTIONS(
  description = "Resource consumption of isolation machinery"
);

-- Summary statistics per scenario
CREATE TABLE IF NOT EXISTS `research.experiment5_tenant_isolation.scenario_summary` (
  scenario STRING NOT NULL,
  total_observations INT64 NOT NULL,
  observer_tenants ARRAY<STRING> NOT NULL,
  max_latency_increase_pct FLOAT64 NOT NULL,
  max_error_rate_increase FLOAT64 NOT NULL,
  avg_effect_size FLOAT64 NOT NULL,
  isolation_works BOOLEAN NOT NULL,  -- Effect size < 0.1 across all metrics
  total_isolation_overhead_cpu_percent FLOAT64 NOT NULL,
  total_isolation_overhead_memory_percent FLOAT64 NOT NULL,
  last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS(
  description = "Summary statistics per fault scenario"
);

-- Baseline periods (normal operation without faults)
CREATE TABLE IF NOT EXISTS `research.experiment5_tenant_isolation.baseline_periods` (
  baseline_id STRING NOT NULL,
  tenant STRING NOT NULL,
  start_timestamp TIMESTAMP NOT NULL,
  end_timestamp TIMESTAMP NOT NULL,
  duration_seconds INT64 NOT NULL,
  avg_p99_latency_ms FLOAT64 NOT NULL,
  avg_error_rate FLOAT64 NOT NULL,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS(
  description = "Baseline performance measurements for comparison"
);
