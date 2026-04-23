.PHONY: help setup tf-init tf-plan tf-apply tf-destroy ansible deploy argocd n8n test lint clean

# Configuration
PROJECT_ID ?= $(shell grep project_id terraform/environments/dev/terraform.tfvars | cut -d'"' -f2)
REGION ?= us-central1
CLUSTER_NAME ?= platform-cluster-dev
ENV ?= dev
DOCKER_REGISTRY ?= us-central1-docker.pkg.dev/$(PROJECT_ID)/platform

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Infrastructure ──────────────────────────────────────────────

setup: ## First-time setup: install tools
	@echo "Installing pre-commit hooks..."
	pip install pre-commit detect-secrets pip-audit semgrep
	pre-commit install
	@echo "Installing Terraform docs..."
	curl -sSLo ./terraform-docs.tar.gz https://terraform-docs.io/dl/v0.17.0/terraform-docs-v0.17.0-$(shell uname -s)-$(shell uname -m).tar.gz
	tar -xzf terraform-docs.tar.gz terraform-docs && mv terraform-docs /usr/local/bin/
	rm terraform-docs.tar.gz
	@echo "Setup complete!"

tf-init: ## Initialize Terraform
	cd terraform/environments/$(ENV) && terraform init -backend-config="bucket=platform-terraform-$(PROJECT_ID)"

tf-plan: ## Run Terraform plan
	cd terraform/environments/$(ENV) && terraform plan -out=tfplan

tf-apply: ## Apply Terraform changes
	cd terraform/environments/$(ENV) && terraform apply tfplan

tf-destroy: ## Destroy Terraform resources (USE WITH CAUTION)
	cd terraform/environments/$(ENV) && terraform destroy

# ── Kubernetes ───────────────────────────────────────────────────

kube-config: ## Get GKE credentials
	gcloud container clusters get-credentials $(CLUSTER_NAME) --region $(REGION) --project $(PROJECT_ID)

deploy-platform: kube-config ## Deploy all platform components
	kubectl apply -f k8s/platform/argocd/namespace.yaml
	kubectl apply -f k8s/platform/istio/namespace.yaml
	kubectl apply -f k8s/platform/gatekeeper/namespace.yaml
	kubectl apply -f k8s/platform/falco/namespace.yaml
	kubectl apply -f k8s/platform/monitoring/namespace.yaml
	kubectl apply -f k8s/platform/cert-manager/install.yaml
	kubectl apply -f k8s/platform/external-secrets/install.yaml
	@echo "Waiting for cert-manager CRDs..."
	sleep 30
	kubectl apply -f k8s/platform/istio/peer-authentication.yaml
	kubectl apply -f k8s/platform/istio/gateway.yaml
	kubectl apply -f k8s/platform/gatekeeper/constraints/
	kubectl apply -f k8s/platform/falco/config.yaml
	kubectl apply -f k8s/platform/monitoring/
	kubectl apply -f k8s/platform/velero/install.yaml

deploy-tools: kube-config ## Deploy platform tools (n8n, Redis)
	kubectl apply -f k8s/platform-tools/n8n/namespace.yaml
	kubectl apply -f k8s/platform-tools/n8n/deployment.yaml
	kubectl apply -f k8s/platform-tools/n8n/istio-virtualservice.yaml

deploy-tenants: kube-config ## Deploy all tenant namespaces
	kubectl apply -f k8s/tenants/tenant-a/
	kubectl apply -f k8s/tenants/tenant-b/
	kubectl apply -f k8s/tenants/tenant-c/

deploy-chaos: kube-config ## Deploy chaos experiments
	kubectl apply -f k8s/chaos/

deploy: deploy-platform deploy-tools deploy-tenants ## Full deployment

# ── Helm ─────────────────────────────────────────────────────────

helm-argocd: ## Install ArgoCD via Helm
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update
	helm upgrade --install argocd argo/argo-cd -n argocd -f k8s/base/helm-values/argocd-values.yaml

helm-istio: ## Install Istio via Helm
	helm repo add istio https://istio-release.storage.googleapis.com/charts
	helm repo update
	helm upgrade --install istio-base istio/base -n istio-system --create-namespace -f k8s/base/helm-values/istio-values.yaml
	helm upgrade --install istiod istio/istiod -n istio-system -f k8s/base/helm-values/istio-values.yaml
	helm upgrade --install istio-ingress istio/gateway -n istio-system -f k8s/base/helm-values/istio-values.yaml

helm-gatekeeper: ## Install OPA Gatekeeper via Helm
	helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
	helm repo update
	helm upgrade --install gatekeeper gatekeeper/gatekeeper -n gatekeeper-system --create-namespace -f k8s/base/helm-values/gatekeeper-values.yaml

helm-falco: ## Install Falco via Helm
	helm repo add falcosecurity https://falcosecurity.github.io/charts
	helm repo update
	helm upgrade --install falco falcosecurity/falco -n falco --create-namespace -f k8s/base/helm-values/falco-values.yaml

helm-n8n: ## Install n8n via Helm
	helm repo add n8n https://n8nio.github.io/n8n-helm-chart
	helm repo update
	helm upgrade --install n8n n8n/n8n -n platform-tools --create-namespace -f k8s/base/helm-values/n8n-values.yaml

helm-all: helm-argocd helm-istio helm-gatekeeper helm-falco helm-n8n ## Install all Helm charts

# ── Docker ───────────────────────────────────────────────────────

docker-build: ## Build Docker image
	docker build -t $(DOCKER_REGISTRY)/app:$(shell git rev-parse --short HEAD) app/

docker-push: docker-build ## Push Docker image to Artifact Registry
	docker push $(DOCKER_REGISTRY)/app:$(shell git rev-parse --short HEAD)

docker-scan: docker-build ## Scan Docker image with Trivy
	trivy image $(DOCKER_REGISTRY)/app:$(shell git rev-parse --short HEAD)

docker-sign: ## Sign Docker image with Cosign
	cosign sign --keyless $(DOCKER_REGISTRY)/app:$(shell git rev-parse --short HEAD)

# ── Ansible ──────────────────────────────────────────────────────

ansible-baseline: ## Run baseline Ansible playbook
	ansible-playbook -i ansible/inventory/dev.yml ansible/playbooks/site.yml --tags baseline

ansible-harden: ## Run node hardening playbook
	ansible-playbook -i ansible/inventory/dev.yml ansible/playbooks/site.yml --tags node-hardening

ansible-monitoring: ## Deploy monitoring agents
	ansible-playbook -i ansible/inventory/dev.yml ansible/playbooks/site.yml --tags monitoring-agent

ansible-all: ## Run all Ansible playbooks
	ansible-playbook -i ansible/inventory/dev.yml ansible/playbooks/site.yml

# ── Testing & Linting ───────────────────────────────────────────

lint: ## Run all linters
	pre-commit run --all-files
	cd terraform/environments/$(ENV) && terraform fmt -check -recursive -diff
	cd terraform/environments/$(ENV) && terraform validate

test: ## Run all tests
	cd app && python -m pytest tests/ -v --cov=app --cov-report=term-missing
	cd terraform && terraform test

test-integration: ## Run integration tests
	cd app && python -m pytest tests/integration/ -v --timeout=60

# ── Research ─────────────────────────────────────────────────────

bq-setup: ## Create BigQuery datasets and tables
	bq mk --dataset --location=US research
	for f in research/bigquery/experiment*.sql; do bq query --use_legacy_sql=false < $$f; done
	bq query --use_legacy_sql=false < research/bigquery/setup_datasets.sql

bq-validate: ## Validate data collection
	@echo "Experiment 1 trials: $$(bq query --use_legacy_sql=false --format=csv 'SELECT COUNT(*) FROM research.experiment1_security_ablation.trials' 2>/dev/null | tail -1)"
	@echo "Experiment 2 trials: $$(bq query --use_legacy_sql=false --format=csv 'SELECT COUNT(*) FROM research.experiment2_automation_mttr.incident_trials' 2>/dev/null | tail -1)"
	@echo "Experiment 3 trials: $$(bq query --use_legacy_sql=false --format=csv 'SELECT COUNT(*) FROM research.experiment3_chaos_slo_calibration.chaos_trials' 2>/dev/null | tail -1)"
	@echo "Experiment 4 runs: $$(bq query --use_legacy_sql=false --format=csv 'SELECT COUNT(*) FROM research.experiment4_ci_gate_effectiveness.gate_executions' 2>/dev/null | tail -1)"
	@echo "Experiment 5 metrics: $$(bq query --use_legacy_sql=false --format=csv 'SELECT COUNT(*) FROM research.experiment5_tenant_isolation.performance_metrics' 2>/dev/null | tail -1)"

research-analyze: ## Run all analysis scripts
	cd research/analysis && pip install -r requirements.txt
	cd research/analysis && python analyze_experiment1.py
	cd research/analysis && python analyze_experiment2.py
	cd research/analysis && python analyze_experiment3.py
	cd research/analysis && python analyze_experiment4.py
	cd research/analysis && python analyze_experiment5.py

# ── Utilities ────────────────────────────────────────────────────

port-forward-grafana: ## Port-forward Grafana
	kubectl port-forward -n monitoring svc/grafana 3000:80

port-forward-n8n: ## Port-forward n8n
	kubectl port-forward -n platform-tools svc/n8n 5678:80

port-forward-argocd: ## Port-forward ArgoCD
	kubectl port-forward -n argocd svc/argocd-server 8080:80

secrets-baseline: ## Generate detect-secrets baseline
	detect-secrets scan --list-all-files > .secrets.baseline

clean: ## Remove generated files
	find . -name "__pycache__" -exec rm -rf {} + 2>/dev/null
	find . -name "*.pyc" -delete 2>/dev/null
	find . -name ".terraform" -exec rm -rf {} + 2>/dev/null
	find . -name "tfplan" -delete 2>/dev/null
	find . -name ".terraform.lock.hcl" -delete 2>/dev/null
	rm -rf app/.pytest_cache app/.coverage app/htmlcov
