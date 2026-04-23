output "cluster_id" {
  description = "ID of the GKE cluster"
  value       = google_container_cluster.autopilot_cluster.id
}

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.autopilot_cluster.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.autopilot_cluster.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.autopilot_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = google_container_cluster.autopilot_cluster.location
}

output "workload_identity_pool" {
  description = "Workload identity pool"
  value       = "${var.project_id}.svc.id.goog"
}
