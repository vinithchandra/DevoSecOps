# Research Infrastructure Quick Start

This guide helps you set up the data collection infrastructure for the research project.

## Prerequisites

- GCP project with appropriate IAM roles
- gcloud CLI installed and authenticated
- Terraform >= 1.8.0
- kubectl >= 1.30.0
- Python 3.11+ (for analysis scripts)

## Step 1: Set Up BigQuery Datasets

```bash
# Navigate to BigQuery schemas directory
cd research/bigquery

# Run the setup script
gcloud bigquery query --use_legacy_sql=false --format=none < setup_datasets.sql

# Verify datasets created
bq ls --datasets research
```

Expected datasets:
- `experiment1_security_ablation`
- `experiment2_automation_mttr`
- `experiment3_chaos_slo_calibration`
- `experiment4_ci_gate_effectiveness`
- `experiment5_tenant_isolation`

## Step 2: Configure GCP Secrets

```bash
# Create secrets for n8n
gcloud secrets create n8n-encryption-key --replication-policy="automatic"
echo "your-encryption-key" | gcloud secrets versions add n8n-encryption-key --data-file=-

# Create secrets for Grafana
gcloud secrets create grafana-admin-password --replication-policy="automatic"
echo "your-admin-password" | gcloud secrets versions add grafana-admin-password --data-file=-
```

## Step 3: Provision Infrastructure

```bash
# Navigate to Terraform environment
cd terraform/environments/dev

# Update terraform.tfvars with your project ID
# terraform.tfvars

# Initialize Terraform
terraform init

# Plan infrastructure
terraform plan

# Apply infrastructure
terraform apply
```

## Step 4: Bootstrap ArgoCD

```bash
# Get GKE credentials
gcloud container clusters get-credentials platform-cluster-dev --region us-central1

# Create ArgoCD namespace
kubectl create namespace argocd

# Apply ArgoCD manifests
kubectl apply -f k8s/platform/argocd/

# Wait for ArgoCD to be ready
kubectl wait --for=condition=Available -n argocd deployment/argocd-server --timeout=300s
```

## Step 5: Deploy Platform Components

```bash
# Apply platform namespace
kubectl apply -f k8s/platform/monitoring/namespace.yaml

# Deploy monitoring stack
kubectl apply -f k8s/platform/monitoring/

# Wait for monitoring components
kubectl wait --for=condition=Available -n monitoring deployment/prometheus-operator --timeout=300s
kubectl wait --for=condition=Available -n monitoring deployment/loki --timeout=300s
kubectl wait --for=condition=Available -n monitoring deployment/grafana --timeout=300s
```

## Step 6: Deploy n8n

```bash
# Create platform-tools namespace
kubectl apply -f k8s/platform-tools/n8n/namespace.yaml

# Deploy n8n
kubectl apply -f k8s/platform-tools/n8n/

# Wait for n8n to be ready
kubectl wait --for=condition=Available -n platform-tools deployment/n8n --timeout=300s
```

## Step 7: Import n8n Workflows

```bash
# Port-forward to n8n
kubectl port-forward -n platform-tools svc/n8n 5678:80

# Open browser to http://localhost:5678
# Import workflows from n8n-workflows/ directory:
# - incident-response-automation.json
# - tenant-onboarding.json
# - dr-drill.json
# - cost-attribution.json
```

## Step 8: Configure GitHub Actions

```bash
# Add secrets to GitHub repository
gh secret set GCP_PROJECT_ID
gh secret set GCP_CREDENTIALS < gcp-credentials.json
gh secret set GITHUB_TOKEN
```

## Step 9: Deploy Chaos Mesh

```bash
# Install Chaos Mesh
kubectl apply -f https://raw.githubusercontent.com/chaos-mesh/chaos-mesh/master/install.sh

# Deploy chaos experiments
kubectl apply -f k8s/chaos/
```

## Step 10: Verify Data Collection

```bash
# Check BigQuery for incoming data
bq query --use_legacy_sql=false "SELECT * FROM \`research.cross_experiment_summary\`"

# Check Grafana dashboards
kubectl port-forward -n monitoring svc/grafana 3000:80
# Open browser to http://localhost:3000
```

## Data Collection Validation

### Experiment 1: Security Ablation
```bash
# Run a test trial
# Verify data in BigQuery
bq query --use_legacy_sql=false "SELECT COUNT(*) FROM \`research.experiment1_security_ablation.trials\`"
```

### Experiment 2: MTTR Automation
```bash
# Trigger a test incident via n8n webhook
# Verify data in BigQuery
bq query --use_legacy_sql=false "SELECT COUNT(*) FROM \`research.experiment2_automation_mttr.incident_trials\`"
```

### Experiment 3: Chaos SLO Calibration
```bash
# Manually trigger a chaos experiment
kubectl apply -f k8s/chaos/pod-kill-experiment.yaml
# Verify data in BigQuery
bq query --use_legacy_sql=false "SELECT COUNT(*) FROM \`research.experiment3_chaos_slo_calibration.chaos_trials\`"
```

### Experiment 4: CI Gate Effectiveness
```bash
# Make a test commit to trigger CI
# Verify data in BigQuery
bq query --use_legacy_sql=false "SELECT COUNT(*) FROM \`research.experiment4_ci_gate_effectiveness.gate_executions\`"
```

### Experiment 5: Tenant Isolation
```bash
# Deploy test tenants
kubectl apply -f k8s/tenants/tenant-a/
kubectl apply -f k8s/tenants/tenant-b/
# Verify data in BigQuery
bq query --use_legacy_sql=false "SELECT COUNT(*) FROM \`research.experiment5_tenant_isolation.performance_metrics\`"
```

## Troubleshooting

### BigQuery Permissions
```bash
# Grant BigQuery Data Editor role to service accounts
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:n8n-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"
```

### GKE Cluster Access
```bash
# Verify cluster is running
gcloud container clusters list

# Verify kubectl context
kubectl config current-context
```

### ArgoCD Sync Issues
```bash
# Check ArgoCD application status
kubectl argo app list

# View application details
kubectl argo app get platform-components
```

### n8n Workflow Failures
```bash
# Check n8n logs
kubectl logs -n platform-tools deployment/n8n

# Check n8n database connection
kubectl exec -n platform-tools deployment/n8n -- env | grep DB
```

## Next Steps

1. Review `research/METHODOLOGY.md` for detailed experiment procedures
2. Review `research/experiments/*/README.md` for experiment-specific instructions
3. Start baseline data collection (minimum 1 week)
4. Begin controlled experiments following the methodology
5. Use `research/analysis/` scripts for statistical analysis

## Monitoring Data Collection

Create a scheduled BigQuery query to monitor data collection progress:

```sql
-- Run daily to check data collection status
SELECT 
  experiment_id,
  experiment_name,
  total_trials,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), first_trial, DAY) as days_running,
  meets_sample_size
FROM `research.cross_experiment_summary`
```

Set up alerts for:
- No new data for 24 hours
- Sample size not met after expected duration
- Data quality anomalies (missing fields, invalid values)
