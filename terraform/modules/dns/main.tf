# DNS Module
# Creates Cloud DNS managed zone for external DNS

resource "google_dns_managed_zone" "dns_zone" {
  name        = var.zone_name
  dns_name    = var.domain_name
  project     = var.project_id
  description = "Managed zone for ${var.domain_name}"
  
  visibility = "public"
  
  dnssec_config {
    state = "on"
  }
}

# DNS records for platform services
resource "google_dns_record_set" "records" {
  for_each = var.dns_records
  
  name         = "${each.key}.${var.domain_name}."
  type         = each.value.type
  ttl          = each.value.ttl
  managed_zone = google_dns_managed_zone.dns_zone.name
  project      = var.project_id
  
  rrdatas = each.value.rrdatas
}
