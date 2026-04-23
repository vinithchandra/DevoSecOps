# Research Methodology

## Overview

This document describes the complete methodology for the research project "Multi-Tenant SaaS Platform: Empirical Analysis of DevSecOps Practices". All experiments are designed to collect publishable empirical evidence from day one.

## Data Collection Infrastructure

### BigQuery Datasets

All experiments write to BigQuery using the schemas defined in `research/bigquery/`:

1. **experiment1_security_ablation** - Security layer ablation study
2. **experiment2_automation_mttr** - Automation impact on MTTR
3. **experiment3_chaos_slo_calibration** - Chaos engineering for SLO calibration
4. **experiment4_ci_gate_effectiveness** - CI gate effectiveness and cost
5. **experiment5_tenant_isolation** - Tenant isolation blast radius

### Data Collection Principles

1. **Precision Timestamps**: All events recorded with microsecond precision for latency calculations
2. **Baseline Periods**: Minimum 1 week of baseline data before fault injection
3. **Versioned Schemas**: All BigQuery schemas version-controlled in Git
4. **Automated Collection**: No manual data entry - all via APIs and n8n workflows
5. **Cross-Experiment Views**: BigQuery views for cross-experiment analysis

## Experiment Methodologies

### Experiment 1: Security Layer Ablation

#### Objective
Quantify the marginal contribution of each security layer (pre-commit, CI Trivy, OPA Gatekeeper, Falco) in detecting attack vectors.

#### Design
- **Ablation Matrix**: 4 layers × 4 attack categories = 16 base combinations
- **Ablation Procedure**: For each attack, test with all layers active, then with each layer turned off one at a time
- **Total Trials**: 64 (4 attacks × 16 combinations per attack)

#### Attack Categories
1. **critical_cve**: Container image with known CRITICAL CVE (pinned old openssl)
2. **hardcoded_secret**: Hardcoded secret in source code (fake AWS key AKIA pattern)
3. **privileged_pod**: Privileged pod manifest (securityContext.privileged: true)
4. **runtime_attack**: Runtime attack (kubectl exec into pod and curl external IP)

#### Data Collection
- **Table**: `research.experiment1_security_ablation.trials`
- **Fields**: trial_id, attack_category, layer_under_test, other_layers_active, detected, detection_latency_seconds, false_positive, raw_log

#### Statistical Analysis
- **Per-layer detection rate**: detected_count / total_trials
- **Chi-squared test**: Test statistical significance of layer contribution
- **Visualization**: Heat map (rows = attack types, columns = layers, cells = detection rate)

#### Sample Size Justification
- 64 trials provides sufficient power for chi-squared test (expected cell counts ≥ 5)
- Each layer tested 16 times (4 attacks × 4 ablation combinations)
- Effect size: Expected to detect 30% difference with 80% power at α=0.05

### Experiment 2: Automation Impact on MTTR

#### Objective
Measure the reduction in Mean Time To Detect (MTTD) and Mean Time To Resolve (MTTR) with n8n-driven automated incident triage vs manual processes.

#### Design
- **Simulated Baseline**: Each scenario run twice (once manual, once automated)
- **Randomization**: Random order to control for learning effects
- **Scenarios**: 8 synthetic incident scenarios

#### Incident Scenarios
1. SLO burn rate breach (error rate spike from bad deploy)
2. Pod OOMKilled (memory limit too low)
3. Certificate expiry warning (cert-manager notification)
4. Cross-tenant network probe (Falco alert)
5. Database connection pool exhaustion
6. Node CPU saturation (HPA not scaling fast enough)
7. Image pull failure (Artifact Registry auth issue)
8. Deployment stuck in Progressing (ArgoCD sync)

#### Data Collection
- **Table**: `research.experiment2_automation_mttr.incident_trials`
- **Fields**: scenario_id, severity, mode, alert_fired_at, first_human_notified_at, incident_ticket_created_at, context_richness_score, correct_root_cause_identified, time_to_correct_rca_seconds, automated_action_taken

#### Context Richness Score
- **Scale**: 1-10
- **0**: Just an alert name
- **10**: Alert + affected pods + recent deploy history + last 50 log lines + suggested remediation
- **Inter-rater agreement**: Two independent reviewers, Cohen's kappa > 0.7 required

#### Statistical Analysis
- **Paired t-test**: Compare MTTR (automated vs manual)
- **Mann-Whitney U test**: Compare context richness scores (non-parametric)
- **Cohen's d**: Effect size calculation
- **Metrics**: Mean, median, 95th-percentile MTTR for both modes

#### Sample Size Justification
- 16 trials (8 scenarios × 2 modes) provides 80% power to detect 50% MTTR reduction at α=0.05
- Paired design increases statistical power
- Consider running 3 repetitions per mode (48 total) if time permits

### Experiment 3: Chaos Engineering for SLO Calibration

#### Objective
Derive empirically-validated SLO alerting thresholds from chaos experiment data and compare with heuristic thresholds.

#### Design
- **Phase A (Calibration)**: 10 fault intensities × 5 runs = 50 trials
- **Phase B (Validation)**: 20 real fault injections with 3 threshold strategies

#### Fault Types
1. **PodChaos**: Kill 10%-100% of worker pods
2. **NetworkChaos**: Add 100ms-1000ms latency to API traffic
3. **DNSChaos**: Block DNS resolution for DB
4. **StressChaos**: CPU stress on tenant nodes
5. **TimeChaos**: Clock skew ±30s

#### Data Collection
- **Table**: `research.experiment3_chaos_slo_calibration.chaos_trials`
- **Fields**: trial_id, fault_type, fault_intensity_pct, observed_error_rate_peak, burn_rate_1h_window, burn_rate_6h_window, slo_breached, recovery_time_seconds, alert_would_fire_at_threshold_*

#### Threshold Strategies
- **H**: Heuristic (Google's 2× and 10× from SRE workbook)
- **E**: Empirically derived from chaos data (90% confidence)
- **O**: Over-sensitive (1× burn rate)

#### Statistical Analysis
- **Dose-response curve**: Fit curve to fault intensity vs burn rate data
- **Threshold derivation**: Find burn rate that maximizes true positive rate while minimizing false positive rate
- **Comparison**: Chi-squared test on false positive rates across strategies

#### Sample Size Justification
- 50 calibration trials provides 5 data points per intensity level
- Sufficient to fit dose-response curve with 95% confidence interval
- 20 validation trials provides sufficient power for comparison

### Experiment 4: CI Gate Effectiveness

#### Objective
Measure true positive rate, false positive rate, and pipeline cost of each security gate in real development.

#### Design
- **Continuous Collection**: Instrument every CI gate from day one
- **Duration**: 8 weeks of active development
- **Manual Classification**: End-of-project classification of all findings

#### Gates Instrumented
1. **pre-commit**: detect-secrets, hadolint, tflint
2. **semgrep**: SAST scanning
3. **pip_audit**: Dependency vulnerability scanning
4. **checkov**: Terraform IaC misconfiguration scanning
5. **trivy_dependency**: Trivy dependency scan
6. **trivy_image**: Trivy container image scan
7. **cosign**: Image signing verification

#### Data Collection
- **Table**: `research.experiment4_ci_gate_effectiveness.gate_executions`
- **Fields**: run_id, commit_sha, gate_name, duration_seconds, result, findings_count, critical_count, high_count, suppressed_count, introduced_by_commit, developer_override

#### Classification Process
- **True Positive**: Real security issue
- **False Positive**: Incorrect or irrelevant finding
- **Configuration Issue**: Gate misconfiguration
- **Inter-rater agreement**: Two reviewers for subset, Cohen's kappa

#### Developer Friction Proxy
- Count of `.trivyignore`, `# nosec`, `# noqa` commits
- Each suppression = proxy for false-positive-driven friction

#### Statistical Analysis
- **Precision**: TP / (TP + FP)
- **Recall**: TP / (TP + FN) (if ground truth available)
- **Pipeline Overhead**: Total seconds added by security gates vs. build/test only
- **Time Series**: Trends over 8 weeks

#### Sample Size Justification
- 8 weeks of development expected to yield 200+ CI runs
- Sufficient for statistically significant precision estimates (±10% at 95% confidence)
- Continuous collection captures natural development patterns

### Experiment 5: Tenant Isolation Blast Radius

#### Objective
Quantify the performance impact of resource-exhausting tenants on co-located tenants.

#### Design
- **Setup**: 3 tenants (tenant-a noisy, tenant-b/c observers)
- **Sampling**: 10-second intervals
- **Phases**: 10 minutes baseline + 10 minutes fault + 10 minutes recovery

#### Fault Scenarios
1. **CPU saturation**: stress-ng pinning all of tenant-a's CPU quota
2. **Memory pressure**: Allocate to OOMKill threshold in tenant-a
3. **Network flood**: Generate high egress traffic from tenant-a
4. **DB connection storm**: Exhaust tenant-a's DB connection pool
5. **Pod churn**: Rapid scale up/down of tenant-a

#### Data Collection
- **Table**: `research.experiment5_tenant_isolation.performance_metrics`
- **Fields**: scenario, tenant, role, timestamp, api_latency_p50_ms, api_latency_p99_ms, api_error_rate, cpu_throttle_rate, pod_restart_count, network_rx_bytes

#### Statistical Analysis
- **Cohen's d**: Effect size between baseline and during-fault periods
- **Isolation Overhead**: CPU and memory consumed by isolation machinery
- **Maximum Impact**: Max latency increase in observer tenants

#### Sample Size Justification
- 5 scenarios × 10 minutes × 6 samples/minute = 300 observations per metric
- Very high statistical power (β > 0.99)
- Sufficient to detect small effect sizes (Cohen's d < 0.1)

## Statistical Rigor

### Hypothesis Testing
- **Alpha Level**: 0.05 for all tests
- **Power Analysis**: Sample sizes calculated for 80% power
- **Multiple Testing**: Bonferroni correction when applicable

### Effect Size Reporting
- **Cohen's d**: For continuous variables (MTTR, latency)
- **Odds Ratio**: For binary outcomes (detection, breach)
- **Confidence Intervals**: 95% CI reported for all estimates

### Reproducibility
- **Random Seeds**: Documented for all stochastic processes
- **Environment Variables**: All configuration in Git
- **Data Versioning**: BigQuery snapshots for each analysis run

## Data Quality Assurance

### Validation Checks
1. **Completeness**: All required fields present
2. **Precision**: Timestamps in microseconds
3. **Consistency**: No duplicate trial IDs
4. **Validity**: Range checks on numeric fields

### Monitoring
- **BigQuery Scheduled Queries**: Daily aggregation of summary statistics
- **Alerts**: On data collection failures or anomalies
- **Dashboard**: Grafana dashboard showing data collection progress

## Ethical Considerations

### Data Privacy
- No personal data collected
- All data anonymized (tenant names, service accounts)
- Compliance with GDPR (no PII)

### Resource Usage
- Chaos experiments limited to non-production hours
- Fault injection bounded (max 50% pods, max 5 minutes)
- Cost monitoring to prevent runaway spending

## Timeline

| Week | Activity |
|------|----------|
| 1 | Setup BigQuery schemas, data collection infrastructure |
| 2 | Baseline data collection (all experiments) |
| 3 | Experiment 1: Security ablation trials |
| 4 | Experiment 2: Manual MTTR trials |
| 5 | Experiment 2: Automated MTTR trials |
| 6 | Experiment 3: Chaos calibration trials |
| 7 | Experiment 3: Chaos validation trials |
| 8 | Experiment 5: Tenant isolation trials |
| 9 | Experiment 4: CI gate data collection (ongoing) |
| 10 | Statistical analysis, visualization, paper writing |

## Success Criteria

### Data Collection
- All 5 experiments meet sample size requirements
- No missing data in critical fields
- Baseline periods collected for all experiments

### Statistical Significance
- p < 0.05 for all primary hypotheses
- Effect sizes reported with confidence intervals
- Inter-rater agreement > 0.7 where applicable

### Publication Readiness
- All experimental procedures documented
- Data and analysis scripts reproducible
- Results formatted for peer review
