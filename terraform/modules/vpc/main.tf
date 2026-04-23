# VPC Module
# Creates a custom VPC with three subnet tiers: public, private, and data

resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "Multi-tier VPC for ${var.project_id}"
}

# Public subnet tier (for load balancers)
resource "google_compute_subnetwork" "public" {
  name          = "${var.vpc_name}-public"
  ip_cidr_range = var.public_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  description   = "Public subnet for load balancers"
  
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }
  
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

# Private subnet tier (for GKE nodes)
resource "google_compute_subnetwork" "private" {
  name          = "${var.vpc_name}-private"
  ip_cidr_range = var.private_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  description   = "Private subnet for GKE nodes"
  private_ip_google_access = true
}

# Data subnet tier (for Cloud SQL)
resource "google_compute_subnetwork" "data" {
  name          = "${var.vpc_name}-data"
  ip_cidr_range = var.data_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  description   = "Data subnet for Cloud SQL"
  private_ip_google_access = true
}

# Cloud Router for Cloud NAT
resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# Cloud NAT for egress from private nodes
resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = ["ALL_SUBNETWORKS_ALL_IP_RANGES"]
  
  log_config {
    enable = true
    filter = "ALL"
  }
}

# VPC Flow Logs
resource "google_compute_subnetwork" "flow_logs" {
  for_each = {
    public  = google_compute_subnetwork.public.id
    private = google_compute_subnetwork.private.id
    data    = google_compute_subnetwork.data.id
  }
  
  name = each.key
  project = var.project_id
  region = var.region
  
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Firewall rules - deny all by default
resource "google_compute_firewall" "deny_all_ingress" {
  name      = "${var.vpc_name}-deny-all-ingress"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  priority  = 65535
  deny {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  deny {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  deny {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}

# Allow SSH from specific CIDRs
resource "google_compute_firewall" "allow_ssh" {
  name      = "${var.vpc_name}-allow-ssh"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  priority  = 1000
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = var.ssh_allowed_cidrs
}

# Allow internal traffic within VPC
resource "google_compute_firewall" "allow_internal" {
  name      = "${var.vpc_name}-allow-internal"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  priority  = 1000
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = [
    var.public_subnet_cidr,
    var.private_subnet_cidr,
    var.data_subnet_cidr,
    var.pods_cidr,
    var.services_cidr
  ]
}

# Allow HTTPS from load balancer health checks
resource "google_compute_firewall" "allow_lb_health_checks" {
  name      = "${var.vpc_name}-allow-lb-health-checks"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  priority  = 1000
  allow {
    protocol = "tcp"
    ports    = ["443", "8080"]
  }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}
