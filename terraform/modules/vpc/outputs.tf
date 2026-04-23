output "vpc_id" {
  description = "ID of the VPC"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = google_compute_network.vpc.name
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = google_compute_subnetwork.public.id
}

output "public_subnet_name" {
  description = "Name of the public subnet"
  value       = google_compute_subnetwork.public.name
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = google_compute_subnetwork.private.id
}

output "private_subnet_name" {
  description = "Name of the private subnet"
  value       = google_compute_subnetwork.private.name
}

output "data_subnet_id" {
  description = "ID of the data subnet"
  value       = google_compute_subnetwork.data.id
}

output "data_subnet_name" {
  description = "Name of the data subnet"
  value       = google_compute_subnetwork.data.name
}

output "pods_cidr" {
  description = "CIDR range for pods"
  value       = var.pods_cidr
}

output "services_cidr" {
  description = "CIDR range for services"
  value       = var.services_cidr
}
