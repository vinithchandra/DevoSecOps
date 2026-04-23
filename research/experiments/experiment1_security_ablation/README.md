# Experiment 1: Security Layer Ablation Study

## Research Question

In a defence-in-depth Kubernetes security stack, what proportion of attack vectors does each individual layer catch, and which combinations are non-redundant?

## Why This Matters

Most DevSecOps literature describes security layers qualitatively. This experiment measures the marginal contribution of each layer with controlled injection of real attack patterns, providing the paper's strongest empirical claim.

## Experimental Design

### The 4×4 Matrix

Four control layers × four attack categories = 16 base combinations. For each, we run ablation (turn layers off one at a time) to test 64 total trials.

**Security Layers:**
1. **pre-commit** - detect-secrets, hadolint, tflint
2. **ci_trivy** - Trivy image and dependency scanning
3. **opa_gatekeeper** - Admission webhook policy validation
4. **falco** - Runtime security monitoring

**Attack Categories:**
1. **critical_cve** - Container image with known CRITICAL CVE (pinned old openssl)
2. **hardcoded_secret** - Hardcoded secret in source code (fake AWS key AKIA pattern)
3. **privileged_pod** - Privileged pod manifest (securityContext.privileged: true, hostPID: true)
4. **runtime_attack** - Runtime attack simulation (kubectl exec into pod and curl external IP)

### Data Collection Schema

Each trial logs to BigQuery table `research.experiment1_security_ablation.trials`:

```json
{
  "trial_id": "uuid",
  "attack_category": "privileged_pod",
  "layer_under_test": "opa_gatekeeper",
  "other_layers_active": ["pre_commit", "ci_trivy"],
  "detected": true,
  "detection_latency_seconds": 4.2,
  "false_positive": false,
  "raw_log": "admission webhook denied: policy privileged-containers"
}
```

### Ablation Procedure

For each attack category:
1. Run with ALL layers active → record result
2. Turn off pre-commit, keep others → run → record
3. Turn off ci_trivy, keep others → run → record
4. Turn off opa_gatekeeper, keep others → run → record
5. Turn off falco, keep others → run → record

This gives per-layer detection rates and marginal contribution.

### Statistical Analysis

- **Per-layer detection rate**: detected_count / total_trials for that layer
- **Per-layer false-positive rate**: false_positive_count / total_trials for that layer
- **Marginal gain**: detection_rate(all_layers) - detection_rate(all_layers - this_layer)
- **Chi-squared test**: Test whether each layer's contribution is statistically significant (χ² test on detection vs non-detection contingency table)

### Visualization

Heat map: rows = attack types, columns = layers, cells = detection rate

### Expected Paper Claim

> "Our ablation study across 64 controlled injection trials shows that OPA Gatekeeper and runtime Falco together catch 94% of attack vectors, while each alone catches only 61% and 38% respectively, demonstrating statistically significant non-redundancy (χ²=18.4, p<0.001)."

## Implementation Steps

1. **Week 1-2**: Set up BigQuery schema, create attack injection scripts
2. **Week 3-4**: Run ablation trials systematically
3. **Week 5**: Statistical analysis and visualization
4. **Week 6**: Write results section for paper

## Scripts

- `inject_critical_cve.sh` - Inject vulnerable package into Dockerfile
- `inject_hardcoded_secret.sh` - Add fake AWS key to source
- `inject_privileged_pod.sh` - Create privileged pod manifest
- `inject_runtime_attack.sh` - Simulate runtime attack
- `run_ablation.sh` - Orchestrates ablation trials
- `analyze_results.py` - Statistical analysis and visualization

## Data Quality Checks

- Ensure each of the 64 trials is completed
- Verify timestamps are recorded with microsecond precision
- Check that raw logs capture detection mechanism
- Validate no missing fields in any trial

## Threats to Validity

- Single cluster, synthetic workloads
- Attack patterns may not reflect real-world sophistication
- Detection latency may vary with cluster load
- Address in paper: relative comparisons remain valid
