variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "service_accounts" {
  description = "Map of service accounts to create"
  type = map(object({
    account_id   = string
    display_name = string
    description  = string
  }))
  default = {
    argocd = {
      account_id   = "argocd-sa"
      display_name = "ArgoCD Service Account"
      description  = "Service account for ArgoCD"
    }
    external-dns = {
      account_id   = "external-dns-sa"
      display_name = "External DNS Service Account"
      description  = "Service account for External DNS"
    }
    cert-manager = {
      account_id   = "cert-manager-sa"
      display_name = "Cert Manager Service Account"
      description  = "Service account for Cert Manager"
    }
    velero = {
      account_id   = "velero-sa"
      display_name = "Velero Service Account"
      description  = "Service account for Velero backups"
    }
    n8n = {
      account_id   = "n8n-sa"
      display_name = "n8n Service Account"
      description  = "Service account for n8n workflows"
    }
  }
}

variable "iam_bindings" {
  description = "IAM bindings for service accounts"
  type = map(object({
    sa_key = string
    role   = string
  }))
  default = {
    argocd-gke = {
      sa_key = "argocd"
      role   = "roles/container.developer"
    }
    external-dns-dns = {
      sa_key = "external-dns"
      role   = "roles/dns.admin"
    }
    cert-manager-dns = {
      sa_key = "cert-manager"
      role   = "roles/dns.admin"
    }
    velero-storage = {
      sa_key = "velero"
      role   = "roles/storage.objectAdmin"
    }
    n8n-bigquery = {
      sa_key = "n8n"
      role   = "roles/bigquery.dataEditor"
    }
    n8n-secrets = {
      sa_key = "n8n"
      role   = "roles/secretmanager.secretAccessor"
    }
    n8n-pubsub = {
      sa_key = "n8n"
      role   = "roles/pubsub.subscriber"
    }
  }
}
