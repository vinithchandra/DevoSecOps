variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "instance_name" {
  description = "Name of the Cloud SQL instance"
  type        = string
  default     = "platform-postgres"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tier" {
  description = "Machine tier for Cloud SQL"
  type        = string
  default     = "db-f1-micro"
}

variable "primary_zone" {
  description = "Primary zone for Cloud SQL"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for private connection"
  type        = string
}

variable "allocated_ip_range" {
  description = "Allocated IP range name"
  type        = string
}

variable "databases" {
  description = "Map of databases to create"
  type        = map(string)
  default = {
    platform = "platform"
    n8n      = "n8n"
  }
}

variable "iam_users" {
  description = "List of IAM service accounts to grant database access"
  type        = list(string)
  default     = []
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}
