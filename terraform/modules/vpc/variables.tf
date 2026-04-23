variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "platform-vpc"
}

variable "public_subnet_cidr" {
  description = "CIDR range for public subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR range for private subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "data_subnet_cidr" {
  description = "CIDR range for data subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "pods_cidr" {
  description = "CIDR range for GKE pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr" {
  description = "CIDR range for GKE services"
  type        = string
  default     = "10.2.0.0/16"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR ranges allowed for SSH access"
  type        = list(string)
  default     = []
}
