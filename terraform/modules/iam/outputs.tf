output "service_account_emails" {
  description = "Email addresses of created service accounts"
  value = {
    for key, sa in google_service_account.service_accounts : key => sa.email
  }
}

output "workload_identity_pool" {
  description = "Workload identity pool resource name"
  value       = google_iam_workload_identity_pool.pool.name
}
