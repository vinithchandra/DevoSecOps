# Terraform GCS Backend Module
# Creates GCS bucket for Terraform state with versioning and IAM

resource "google_storage_bucket" "terraform_state" {
  name          = "${var.bucket_name_prefix}-${var.project_id}"
  project       = var.project_id
  location      = var.location
  force_destroy = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = var.state_retention_days
    }
    action {
      type = "SetStorageClass"
      storage_class = "COLD"
    }
  }

  uniform_bucket_level_access = true

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "terraform-state"
  }
}

resource "google_storage_bucket_iam_binding" "admin" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.admin"
  members = var.admin_members
}

resource "google_storage_bucket_iam_binding" "viewer" {
  count = length(var.viewer_members) > 0 ? 1 : 0

  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectViewer"
  members = var.viewer_members
}

resource "google_storage_bucket" "velero_backups" {
  name          = "${var.bucket_name_prefix}-velero-${var.project_id}"
  project       = var.project_id
  location      = var.location
  force_destroy = false

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "velero-backups"
  }
}

resource "google_storage_bucket" "app_logs" {
  name          = "${var.bucket_name_prefix}-logs-${var.project_id}"
  project       = var.project_id
  location      = var.location
  force_destroy = true

  lifecycle_rule {
    condition {
      age = var.log_retention_days
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "application-logs"
  }
}
