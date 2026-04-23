output "terraform_state_bucket" {
  description = "GCS bucket for Terraform state"
  value       = google_storage_bucket.terraform_state.name
}

output "velero_backup_bucket" {
  description = "GCS bucket for Velero backups"
  value       = google_storage_bucket.velero_backups.name
}

output "app_logs_bucket" {
  description = "GCS bucket for application logs"
  value       = google_storage_bucket.app_logs.name
}
