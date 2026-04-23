variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "GCS bucket location"
  type        = string
  default     = "US"
}

variable "bucket_name_prefix" {
  description = "Prefix for GCS bucket names"
  type        = string
  default     = "platform"
}

variable "state_retention_days" {
  description = "Days before Terraform state moves to Coldline storage"
  type        = number
  default     = 365
}

variable "log_retention_days" {
  description = "Days before application logs are deleted"
  type        = number
  default     = 90
}

variable "admin_members" {
  description = "List of members with storage admin access"
  type        = list(string)
  default     = []
}

variable "viewer_members" {
  description = "List of members with object viewer access"
  type        = list(string)
  default     = []
}
