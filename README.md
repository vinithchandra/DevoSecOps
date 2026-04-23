# Multi-Tenant SaaS Platform - DevSecOps Research Project

**Production-grade DevSecOps reference platform on Google Cloud Platform**

## Research Overview

This project implements a complete multi-tenant SaaS platform with full DevSecOps lifecycle on GCP. The platform is designed as a production-grade, advanced-level research project integrating every major DevOps discipline into a single cohesive system.

### Research Objectives

This research aims to empirically validate the effectiveness of DevSecOps practices through five controlled experiments:

1. **Security Layer Ablation Study**: Quantify the marginal contribution of each security layer (pre-commit, CI Trivy, OPA Gatekeeper, Falco) in detecting attack vectors
2. **Automation Impact on MTTR**: Measure the reduction in Mean Time To Resolve with n8n-driven automated incident triage vs manual processes
3. **Chaos Engineering for SLO Calibration**: Derive empirically-validated SLO alerting thresholds from chaos experiment data
4. **CI Pipeline Gate Effectiveness**: Measure true/false positive rates and cost of each security gate in real development
5. **Tenant Isolation Blast Radius**: Quantify performance impact of resource-exhausting tenants on co-located tenants

### Publication Target

This project is designed for publication as a research paper. All experiments are instrumented from day one to collect publishable empirical evidence.

## Architecture

### System Layers

1. **Developer workstation** - Code authoring, local validation (Git, pre-commit, Docker)
2. **CI pipeline** - Build, test, security scan, push (GitHub Actions, Trivy, Semgrep)
3. **Infrastructure (IaC)** - Provision GCP resources (Terraform, Ansible, GCS state)
4. **CD / Runtime** - Deploy, operate Kubernetes workloads (ArgoCD, GKE Autopilot, Helm, Istio)
5. **Workflow automation** - Event-driven operational workflows (n8n on GKE)
6. **Observability** - Metrics, logs, traces, alerting (Prometheus, Grafana LGTM, OTel)
7. **Security** - Policy, secrets, runtime, compliance (OPA, Falco, Cosign, SCC)

### GCP Services

- **GKE Autopilot** - Primary Kubernetes runtime (multi-region, private cluster, Workload Identity)
- **Cloud SQL (Postgres)** - Database for tenants + n8n state (private IP, HA standby)
- **Artifact Registry** - Container image store (Trivy scanning enabled)
- **GCS** - Terraform state, Velero backups, n8n exports (versioning, CMEK encrypted)
- **Cloud DNS** - External DNS for ingress hostnames
- **GCP Secret Manager** - Canonical secret store (Workload Identity access)
- **Cloud Pub/Sub** - Event bus for infra events to n8n
- **BigQuery** - Cost attribution, compliance reporting, research data collection
- **VPC + Cloud NAT** - Private networking, egress (no public IPs on nodes)
- **Security Command Center** - Compliance posture, findings

## Repository Structure

```
platform/
├── terraform/
│   ├── modules/          # Reusable: vpc, gke, cloudsql, iam, dns
│   └── environments/     # dev / staging / prod tfvars
├── ansible/
│   └── roles/            # node-hardening, monitoring-agent, baseline
├── k8s/
│   ├── base/             # Shared Helm charts (apps, infra components)
│   ├── tenants/          # Per-tenant Helm values overlays
│   └── platform/         # ArgoCD, Istio, Gatekeeper, Falco, n8n, cert-manager
├── .github/
│   └── workflows/        # ci.yml, tf-plan.yml, tf-apply.yml, deploy.yml
├── n8n-workflows/        # Exported n8n workflow JSONs (version-controlled)
├── monitoring/
│   ├── dashboards/       # Grafana dashboard JSON
│   └── alerts/           # PrometheusRule YAML, PagerDuty config
└── research/
    ├── experiments/      # Experiment definitions and scripts
    ├── bigquery/         # BigQuery schemas for data collection
    └── analysis/         # Analysis notebooks and scripts
```

## Implementation Timeline

| Week | Phase | Milestone |
|------|-------|-----------|
| 1 | Foundation | VPC, GKE, Cloud SQL provisioned via Terraform |
| 2 | Foundation + CI | Ansible hardening complete. GitHub Actions CI with Trivy + Semgrep |
| 3 | Kubernetes runtime | GKE cluster running. ArgoCD installed. Platform namespace healthy |
| 4 | Multi-tenant runtime | 2 tenant namespaces with full isolation |
| 5 | GitOps + Mesh | Istio mTLS enforced. ArgoCD ApplicationSet managing all tenants |
| 6 | Observability | Grafana LGTM stack live. OTel traces correlated with logs |
| 7 | n8n + Security | n8n deployed, 4 workflows operational. Falco + OPA enforced |
| 8 | Chaos + DR | Chaos Mesh experiments passing. Velero DR drill complete |
| 9-10 | Advanced challenges | Progressive delivery, cost attribution, zero-trust, multi-region |

## Success Criteria

1. Zero manual GCP console actions (terraform plan shows no diff)
2. CI blocks on CRITICAL CVE (verified with vulnerable package)
3. All images are Cosign-signed (verified via admission annotations)
4. Cross-tenant traffic is blocked (verified via NetworkPolicy)
5. SLO dashboard is live (Grafana shows 28-day availability burn rate)
6. n8n incident workflow fires (PagerDuty ticket created with logs)
7. Tenant onboarding is automated (< 5 min from webhook to DNS)
8. DR drill passes SLO (Chaos Mesh validates recovery time)
9. Full restore from backup (Velero restore validates data integrity)
10. Traces link to logs (Grafana Explore correlation)

## Getting Started

### Prerequisites

- GCP project with appropriate IAM roles
- Terraform >= 1.8
- Ansible >= 2.16
- kubectl >= 1.30
- helm >= 3.15
- Docker (local development)
- GitHub account with Actions enabled

### Initial Setup

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd platform
   ```

2. **Configure GCP authentication**
   ```bash
   gcloud auth application-default login
   ```

3. **Initialize Terraform state**
   ```bash
   cd terraform/environments/dev
   terraform init
   ```

4. **Plan and apply infrastructure**
   ```bash
   terraform plan
   terraform apply
   ```

5. **Configure kubectl context**
   ```bash
   gcloud container clusters get-credentials <cluster-name> --region <region>
   ```

6. **Bootstrap ArgoCD**
   ```bash
   kubectl apply -f k8s/platform/argocd/bootstrap/
   ```

## Research Data Collection

All experiments write to BigQuery using the schemas defined in `research/bigquery/`. Data collection is automated from day one:

- **Experiment 1**: Security ablation (64 trials, 4-layer × 4-attack matrix)
- **Experiment 2**: MTTR automation (8 scenarios × 2 modes = 16+ trials)
- **Experiment 3**: SLO calibration (50 trials across 10 intensity levels)
- **Experiment 4**: CI gate effectiveness (continuous over 8 weeks)
- **Experiment 5**: Tenant isolation (5 scenarios × 10-minute sampling)

See `research/experiments/` for detailed methodology.

## Tools & Versions

| Tool | Version | Role |
|------|---------|------|
| Terraform | ~> 1.8 | Infrastructure provisioning |
| Ansible | ~> 2.16 | Node configuration |
| GitHub Actions | Latest | CI pipeline |
| ArgoCD | ~> 2.11 | GitOps CD |
| GKE Autopilot | 1.30+ | Kubernetes runtime |
| Helm | ~> 3.15 | Package manager |
| Istio | ~> 1.22 | Service mesh |
| Prometheus | ~> 2.52 | Metrics collection |
| Grafana | ~> 11.0 | Dashboards + alerting |
| Loki | ~> 3.0 | Log aggregation |
| Tempo | ~> 2.5 | Distributed tracing |
| OPA Gatekeeper | ~> 3.16 | Admission control |
| Falco | ~> 0.38 | Runtime security |
| Trivy | ~> 0.52 | Vulnerability scanning |
| Cosign | ~> 2.2 | Image signing |
| n8n | ~> 1.50 | Workflow automation |
| OpenTelemetry | ~> 0.102 | Telemetry pipeline |

## License

This project is part of a research initiative. See LICENSE file for details.

## Contact

For research collaboration inquiries, contact the project maintainers.
