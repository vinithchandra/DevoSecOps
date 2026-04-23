# Data Analysis Guide

This guide provides scripts and procedures for analyzing the collected research data.

## Setup

```bash
cd research/analysis

# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

## Analysis Scripts

### Experiment 1: Security Ablation Analysis

```bash
python analyze_experiment1.py --dataset experiment1_security_ablation
```

**Outputs:**
- `results/experiment1/layer_effectiveness.csv` - Per-layer detection rates
- `results/experiment1/heat_map.png` - Heat map visualization
- `results/experiment1/chi_squared_test.json` - Statistical test results

**Key Metrics:**
- Per-layer detection rate
- Per-layer false-positive rate
- Chi-squared statistic and p-value
- Heat map visualization

### Experiment 2: MTTR Automation Analysis

```bash
python analyze_experiment2.py --dataset experiment2_automation_mttr
```

**Outputs:**
- `results/experiment2/mttr_comparison.csv` - Manual vs automated MTTR
- `results/experiment2/context_richness.csv` - Context richness scores
- `results/experiment2/paired_t_test.json` - Statistical test results

**Key Metrics:**
- Mean, median, 95th-percentile MTTR
- Context richness scores (mean, median)
- Paired t-test statistic and p-value
- Cohen's d effect size

### Experiment 3: Chaos SLO Calibration Analysis

```bash
python analyze_experiment3.py --dataset experiment3_chaos_slo_calibration
```

**Outputs:**
- `results/experiment3/dose_response_curve.png` - Fault intensity vs burn rate
- `results/experiment3/threshold_comparison.csv` - Threshold strategy comparison
- `results/experiment3/derived_thresholds.json` - Recommended thresholds

**Key Metrics:**
- Dose-response curve parameters
- False positive rate per threshold strategy
- Empirically derived threshold values
- 95% confidence intervals

### Experiment 4: CI Gate Effectiveness Analysis

```bash
python analyze_experiment4.py --dataset experiment4_ci_gate_effectiveness
```

**Outputs:**
- `results/experiment4/gate_effectiveness.csv` - Per-gate precision/recall
- `results/experiment4/pipeline_cost.csv` - Pipeline duration breakdown
- `results/experiment4/suppression_analysis.csv` - Developer friction metrics

**Key Metrics:**
- Per-gate precision and recall
- Pipeline overhead (seconds)
- Suppression rate per gate
- Time series trends

### Experiment 5: Tenant Isolation Analysis

```bash
python analyze_experiment5.py --dataset experiment5_tenant_isolation
```

**Outputs:**
- `results/experiment5/effect_size_analysis.csv` - Cohen's d per metric
- `results/experiment5/isolation_overhead.csv` - Resource overhead
- `results/experiment5/blast_radius_summary.json` - Summary statistics

**Key Metrics:**
- Cohen's d for each metric (baseline vs fault)
- Maximum latency increase
- Isolation overhead (CPU, memory percentages)
- Error rate attributable to neighbour faults

## Cross-Experiment Analysis

```bash
python cross_experiment_analysis.py
```

**Outputs:**
- `results/cross_experiment/summary.json` - Combined results
- `results/cross_experiment/publication_tables.tex` - LaTeX tables for paper
- `results/cross_experiment/figures/` - Publication-ready figures

## Visualization

### Generate All Figures

```bash
python generate_figures.py
```

**Outputs:**
- `results/figures/` - PNG and PDF versions of all figures
- Figure naming convention: `figure_{experiment}_{metric}.{ext}`

### Custom Visualizations

```python
import matplotlib.pyplot as plt
import pandas as pd
from google.cloud import bigquery

# Query data
client = bigquery.Client()
query = "SELECT * FROM `research.experiment1_security_ablation.trials`"
df = client.query(query).to_dataframe()

# Create custom plot
plt.figure(figsize=(10, 6))
plt.bar(df['layer_under_test'], df['detection_rate'])
plt.xlabel('Security Layer')
plt.ylabel('Detection Rate')
plt.title('Security Layer Effectiveness')
plt.savefig('results/figures/custom_plot.png')
```

## Statistical Analysis

### Power Analysis

```bash
python power_analysis.py --experiment 1 --effect_size 0.5 --alpha 0.05 --power 0.8
```

### Effect Size Calculation

```python
from scipy import stats
import numpy as np

def cohens_d(group1, group2):
    n1, n2 = len(group1), len(group2)
    var1, var2 = np.var(group1, ddof=1), np.var(group2, ddof=1)
    pooled_var = ((n1-1)*var1 + (n2-1)*var2) / (n1+n2-2)
    d = (np.mean(group1) - np.mean(group2)) / np.sqrt(pooled_var)
    return d
```

### Confidence Intervals

```python
import scipy.stats as st

def confidence_interval(data, confidence=0.95):
    data = np.array(data)
    mean = np.mean(data)
    sem = st.sem(data)
    ci = st.t.interval(confidence, len(data)-1, loc=mean, scale=sem)
    return ci
```

## Publication-Ready Outputs

### LaTeX Tables

```bash
python generate_latex_tables.py
```

**Outputs:**
- `results/tables/table1_ablation.tex` - Experiment 1 results
- `results/tables/table2_mttr.tex` - Experiment 2 results
- `results/tables/table3_chaos.tex` - Experiment 3 results
- `results/tables/table4_ci_gates.tex` - Experiment 4 results
- `results/tables/table5_isolation.tex` - Experiment 5 results

### Figure Export

```bash
# Export all figures in publication format (300 DPI, PDF)
python export_figures.py --format pdf --dpi 300
```

### Statistical Reporting

```bash
python generate_statistical_report.py
```

**Outputs:**
- `results/statistical_report.md` - Markdown report with all statistics
- `results/statistical_report.tex` - LaTeX version for paper

## Data Quality Checks

```bash
python data_quality_check.py
```

**Checks:**
- Missing values
- Duplicate records
- Timestamp precision
- Value ranges
- Data type consistency

## Reproducibility

### Set Random Seeds

```python
import numpy as np
import random

np.random.seed(42)
random.seed(42)
```

### Version Control

```bash
# Tag analysis commit with data snapshot
git tag -a analysis-v1.0 -m "Analysis for paper submission"
git push origin analysis-v1.0
```

### Environment Snapshot

```bash
# Freeze Python dependencies
pip freeze > requirements.lock

# Record BigQuery schema versions
bq show --schema --format=prettyjson research.experiment1_security_ablation.trials > schema_experiment1.json
```

## Troubleshooting

### BigQuery Query Errors

```python
# Check query syntax
from google.cloud import bigquery
client = bigquery.Client()
job = client.query("YOUR_QUERY")
job.errors  # Check for errors
```

### Memory Issues with Large Datasets

```python
# Use chunked queries
query = """
SELECT * FROM `research.experiment5_tenant_isolation.performance_metrics`
WHERE timestamp >= @start_time
"""
query_params = [bigquery.ScalarQueryParameter("start_time", "TIMESTAMP", "2026-04-01T00:00:00Z")]
job_config = bigquery.QueryJobConfig(query_parameters=query_params)
df = client.query(query, job_config=job_config).to_dataframe()
```

### Plotting Issues

```python
# Set matplotlib backend to Agg for headless environments
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
```

## Next Steps

1. Run all analysis scripts
2. Review generated figures and tables
3. Perform additional custom analyses as needed
4. Export publication-ready outputs
5. Update research paper with results
6. Archive analysis code and data snapshots
