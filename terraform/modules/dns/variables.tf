variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "zone_name" {
  description = "Name of the DNS managed zone"
  type        = string
  default     = "platform-zone"
}

variable "domain_name" {
  description = "Domain name for the zone"
  type        = string
}

variable "dns_records" {
  description = "DNS records to create"
  type = map(object({
    type    = string
    ttl     = number
    rrdatas = list(string)
  }))
  default = {
    api = {
      type    = "A"
      ttl     = 300
      rrdatas = ["10.0.0.1"]
    }
    grafana = {
      type    = "CNAME"
      ttl     = 300
      rrdatas = ["ghs.googlehosted.com."]
    }
  }
}
