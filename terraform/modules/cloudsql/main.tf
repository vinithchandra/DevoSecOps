# Cloud SQL Module
# Creates a PostgreSQL instance with HA standby

resource "google_sql_database_instance" "postgres" {
  name             = var.instance_name
  project          = var.project_id
  region           = var.region
  database_version = "POSTGRES_15"
  
  settings {
    tier = var.tier
    edition = "ENTERPRISE"
    
    # Availability configuration
    availability_type = "REGIONAL"
    activation_policy = "ALWAYS"
    
    # Backup configuration
    backup_configuration {
      enabled            = true
      start_time         = "02:00"
      location           = var.region
      transaction_log_retention_days = 7
      retained_backups  = 30
      backup_retention_settings {
        retained_backups = 30
        retention_unit   = "COUNT"
      }
    }
    
    # Database flags
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
    
    database_flags {
      name  = "max_connections"
      value = "100"
    }
    
    # IP configuration
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_id
      allocated_ip_range = var.allocated_ip_range
      
      # Authorized networks (empty for private only)
      authorized_networks {
        name  = "restricted-access"
        value = "0.0.0.0/0"
      }
      
      # SSL configuration
      ssl_mode = "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"
      
      # Require SSL
      require_ssl = true
    }
    
    # Location configuration
    location_preference {
      zone = var.primary_zone
    }
    
    # Maintenance window
    maintenance_window {
      day          = 7
      hour         = 2
      update_track = "stable"
    }
    
    # User labels
    user_labels = {
      env        = var.environment
      managed_by = "terraform"
      project    = "platform"
    }
    
    # Pricing plan
    pricing_plan = "PER_USE"
    
    # Deletion protection
    deletion_protection_enabled = var.deletion_protection
  }
  
  depends_on = [google_service_networking_connection.private_vpc_connection]
  
  deletion_protection = var.deletion_protection
}

# Private VPC connection
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# Allocate IP range for Cloud SQL
resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.instance_name}-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_id
}

# Create databases
resource "google_sql_database" "databases" {
  for_each    = var.databases
  name        = each.key
  instance    = google_sql_database_instance.postgres.name
  charset     = "UTF8"
  collation   = "en_US.UTF8"
  
  depends_on = [google_sql_database_instance.postgres]
}

# IAM database authentication
resource "google_sql_user" "iam_users" {
  for_each = var.iam_users
  name     = each.value
  instance = google_sql_database_instance.postgres.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
  
  depends_on = [google_sql_database_instance.postgres]
}
