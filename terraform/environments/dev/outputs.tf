output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "cloudsql_connection_name" {
  description = "Cloud SQL connection name"
  value       = module.cloudsql.instance_connection_name
}

output "service_account_emails" {
  description = "Service account emails"
  value       = module.iam.service_account_emails
}

output "terraform_state_bucket" {
  description = "GCS bucket for Terraform state"
  value       = module.gcs.terraform_state_bucket
}

output "velero_backup_bucket" {
  description = "GCS bucket for Velero backups"
  value       = module.gcs.velero_backup_bucket
}

output "bigquery_dataset_ids" {
  description = "BigQuery dataset IDs for research"
  value       = module.bigquery.dataset_ids
}
