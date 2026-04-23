# Dev Environment Terraform Configuration
# This is the root module that calls all sub-modules

terraform {
  required_version = ">= 1.8.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
  
  backend "gcs" {
    bucket = "platform-terraform-state-dev"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"
  
  project_id         = var.project_id
  region             = var.region
  vpc_name           = "${var.project_id}-vpc-dev"
  ssh_allowed_cidrs  = var.ssh_allowed_cidrs
}

# GKE Module
module "gke" {
  source = "../../modules/gke"
  
  project_id              = var.project_id
  region                  = var.region
  cluster_name            = "${var.project_id}-cluster-dev"
  environment             = "dev"
  vpc_name                = module.vpc.vpc_name
  private_subnet_name     = module.vpc.private_subnet_name
  master_ipv4_cidr        = var.master_ipv4_cidr
  authorized_network_cidr = var.authorized_network_cidr
  workload_identity_bindings = var.workload_identity_bindings
}

# Cloud SQL Module
module "cloudsql" {
  source = "../../modules/cloudsql"
  
  project_id          = var.project_id
  region              = var.region
  instance_name       = "${var.project_id}-postgres-dev"
  environment         = "dev"
  tier                = var.db_tier
  primary_zone        = var.primary_zone
  vpc_id              = module.vpc.vpc_id
  allocated_ip_range  = "${var.project_id}-ip-range-dev"
  deletion_protection = false
}

# IAM Module
module "iam" {
  source = "../../modules/iam"
  
  project_id    = var.project_id
  region        = var.region
  cluster_name  = module.gke.cluster_name
}

# DNS Module
module "dns" {
  source = "../../modules/dns"
  
  project_id  = var.project_id
  zone_name   = "${var.project_id}-zone-dev"
  domain_name = var.domain_name
}

# GCS Buckets Module (Terraform state, Velero backups, logs)
module "gcs" {
  source = "../../modules/gcs"
  
  project_id    = var.project_id
  environment   = "dev"
  location      = "US"
  admin_members = ["serviceAccount:terraform-sa@${var.project_id}.iam.gserviceaccount.com"]
}

# BigQuery Module (Research data collection)
module "bigquery" {
  source = "../../modules/bigquery"
  
  project_id = var.project_id
  environment = "dev"
  
  service_account_editors = {
    "n8n-editor" = ["serviceAccount:n8n-sa@${var.project_id}.iam.gserviceaccount.com"]
    "ci-editor"  = ["serviceAccount:ci-logger-sa@${var.project_id}.iam.gserviceaccount.com"]
  }
}
