# Experiment 4: CI Pipeline Gate Effectiveness and Cost

## Research Question

What is the true positive rate, false positive rate, and pipeline cost (in seconds and developer friction) of each security gate in a real DevSecOps CI pipeline?

## Why This Matters

CI security gate literature is almost entirely vendor claims. This experiment measures real gate performance on a real codebase over weeks of actual development.

## Experimental Design

### Continuous Data Collection

Instrument every CI gate from day one. Add a GitHub Actions step that writes to BigQuery after every CI run.

### Gates Instrumented

1. **pre_commit** - detect-secrets, hadolint, tflint
2. **semgrep** - SAST scanning
3. **pip_audit** / **npm_audit** - Dependency vulnerability scanning
4. **checkov** - Terraform IaC misconfiguration scanning
5. **trivy_dependency** - Trivy dependency scan
6. **trivy_image** - Trivy container image scan
7. **cosign** - Image signing verification

### Data Collection Schema

Each gate execution logs to BigQuery table `research.experiment4_ci_gate_effectiveness.gate_executions`:

```json
{
  "run_id": "github_run_12345",
  "commit_sha": "abc123",
  "gate": "trivy_image_scan",
  "duration_seconds": 47,
  "result": "pass",
  "findings_count": 0,
  "critical_count": 0,
  "high_count": 2,
  "suppressed_count": 3,
  "introduced_by_commit": false,
  "developer_override": false
}
```

### Classification Process

At the end of the project, manually classify each failure:
- **True positive**: Real security issue
- **False positive**: Incorrect or irrelevant finding
- **Configuration issue**: Gate misconfiguration

This gives per-gate precision (TP / (TP + FP)) and recall.

### Developer Friction Proxy

Count the number of times a developer commits:
- `.trivyignore` file
- `# nosec` comment (Python)
- `# noqa` comment (Python)
- `// eslint-disable-next-line` (JavaScript)

Each suppression is a proxy for false-positive-driven friction.

### Statistical Analysis

- **Per-gate precision**: TP / (TP + FP)
- **Per-gate recall**: TP / (TP + FN) (if ground truth available)
- **Pipeline overhead**: Total seconds added by security gates vs. build/test only
- **Suppression rate**: Suppressions / total findings per gate
- **Time series analysis**: Trends over 8 weeks

### Expected Paper Claim

> "Across 312 CI pipeline runs over 8 weeks, Trivy image scanning achieved 94% precision with 4.2 false positives per week, while Semgrep SAST showed higher false positive rate (61% precision) but caught 3 true positive vulnerabilities that no other gate detected, contributing unique signal at a cost of 23 additional seconds per run."

## Implementation Steps

1. **Week 1**: Add instrumentation to GitHub Actions workflow
2. **Week 2-9**: Continuous data collection during normal development
3. **Week 10**: Manual classification of all findings
4. **Week 10**: Statistical analysis, write results section

## GitHub Actions Integration

Add this step to CI pipeline:

```yaml
- name: Log CI Gate Results to BigQuery
  if: always()
  uses: google-github-actions/bigquery@v1
  with:
    project_id: ${{ secrets.GCP_PROJECT_ID }}
    credentials_json: ${{ secrets.GCP_CREDENTIALS }}
    query: |
      INSERT INTO `research.experiment4_ci_gate_effectiveness.gate_executions`
      VALUES ...
```

## Scripts

- `add_bigquery_logging.sh` - Adds BigQuery logging to CI workflow
- `classify_findings.py` - Helps manually classify findings
- `analyze_ci_gates.py` - Statistical analysis and visualization
- `calculate_pipeline_cost.py` - Calculates time and cost overhead

## Data Quality Checks

- Ensure every CI run logs results for all gates
- Verify timestamps are recorded for each gate
- Check that duration_seconds is accurate
- Validate no missing fields in any execution

## Metrics to Track

- Total CI runs per week
- Average pipeline duration
- Gate pass/fail rates
- Findings per gate per week
- Suppressions per gate per week
- True positive rate per gate
- False positive rate per gate
- Pipeline overhead percentage

## Threats to Validity

- Single codebase may not be representative
- Manual classification may have reviewer bias
- 8 weeks may be insufficient for rare events
- Address in paper: methodology is reproducible, relative comparisons valid
