variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "platform-cluster"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "private_subnet_name" {
  description = "Name of the private subnet"
  type        = string
}

variable "master_ipv4_cidr" {
  description = "CIDR range for GKE master endpoint"
  type        = string
  default     = "172.16.0.0/28"
}

variable "authorized_network_cidr" {
  description = "CIDR range authorized to access GKE master"
  type        = string
  default     = "10.0.0.0/16"
}

variable "workload_identity_bindings" {
  description = "Map of workload identity bindings"
  type = map(object({
    gcp_sa_id    = string
    namespace    = string
    k8s_sa_name  = string
  }))
  default = {}
}
