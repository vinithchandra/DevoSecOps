output "zone_name" {
  description = "Name of the DNS zone"
  value       = google_dns_managed_zone.dns_zone.name
}

output "name_servers" {
  description = "Name servers for the zone"
  value       = google_dns_managed_zone.dns_zone.name_servers
}
