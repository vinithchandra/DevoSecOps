# IAM Module
# Creates service accounts and IAM bindings with least privilege

# Service accounts for platform components
resource "google_service_account" "service_accounts" {
  for_each = var.service_accounts
  
  account_id   = each.value.account_id
  display_name = each.value.display_name
  description  = each.value.description
  project      = var.project_id
}

# IAM bindings for service accounts
resource "google_project_iam_member" "project_bindings" {
  for_each = var.iam_bindings
  
  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.service_accounts[each.value.sa_key].email}"
}

# Workload Identity Federation bindings
resource "google_iam_workload_identity_pool" "pool" {
  provider                  = google-beta
  project                   = var.project_id
  workload_identity_pool_id = "${var.project_id}-pool"
  display_name              = "Workload Identity Pool"
  description               = "Workload Identity Pool for GKE"
}

resource "google_iam_workload_identity_pool_provider" "provider" {
  provider                           = google-beta
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "${var.project_id}-provider"
  display_name                       = "Workload Identity Provider"
  description                        = "Workload Identity Provider for GKE"
  
  oidc {
    issuer_uri = "https://container.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/clusters/${var.cluster_name}"
  }
  
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.namespace" = "assertion.kubernetes.namespace"
    "attribute.service"   = "assertion.kubernetes.serviceaccount.name"
  }
}

# Organization policy constraints
resource "google_project_organization_policy" "restrict_public_ips" {
  project     = var.project_id
  constraint  = "compute.vmExternalIpAccess"
  
  list_policy {
    allow {
      values = []
    }
  }
}

resource "google_project_organization_policy" "enforce_workload_identity" {
  project    = var.project_id
  constraint = "iam.disableWorkloadIdentityClusterCreation"
  
  boolean_policy {
    enforced = false
  }
}

resource "google_project_organization_policy" "deny_default_sa" {
  project    = var.project_id
  constraint = "iam.automaticIamGrantsForDefaultServiceAccounts"
  
  boolean_policy {
    enforced = true
  }
}
