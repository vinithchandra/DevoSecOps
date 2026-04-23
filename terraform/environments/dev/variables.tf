variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR ranges allowed for SSH"
  type        = list(string)
  default     = []
}

variable "master_ipv4_cidr" {
  description = "CIDR for GKE master"
  type        = string
  default     = "172.16.0.0/28"
}

variable "authorized_network_cidr" {
  description = "Authorized network for GKE master"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_tier" {
  description = "Cloud SQL tier"
  type        = string
  default     = "db-f1-micro"
}

variable "primary_zone" {
  description = "Primary zone for Cloud SQL"
  type        = string
  default     = "us-central1-a"
}

variable "domain_name" {
  description = "Domain name"
  type        = string
  default     = "platform.dev.local"
}

variable "workload_identity_bindings" {
  description = "Workload identity bindings"
  type = map(object({
    gcp_sa_id   = string
    namespace   = string
    k8s_sa_name = string
  }))
  default = {}
}
