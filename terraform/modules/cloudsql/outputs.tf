output "instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.name
}

output "instance_connection_name" {
  description = "Connection name for Cloud SQL"
  value       = google_sql_database_instance.postgres.connection_name
}

output "private_ip_address" {
  description = "Private IP address of the instance"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "database_names" {
  description = "List of database names"
  value       = [for db in google_sql_database.databases : db.name]
}
