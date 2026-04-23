# GKE Autopilot Module
# Creates a private GKE Autopilot cluster with Workload Identity

resource "google_container_cluster" "autopilot_cluster" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Enable Autopilot mode
  enable_autopilot = true

  # Network configuration
  network    = var.vpc_name
  subnetwork = var.private_subnet_name

  # Private cluster configuration
  private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes    = true
    master_ipv4_cidr_block  = var.master_ipv4_cidr
  }

  # Master authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.authorized_network_cidr
      display_name = "authorized-network"
    }
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Binary Authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Release channel
  release_channel {
    channel = "REGULAR"
  }

  # Network policy (Calico)
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Pod security policy
  pod_security_policy_config {
    enabled = false # Using PodSecurityAdmission instead
  }

  # Maintenance window
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T00:00:00Z"
      end_time   = "2024-01-01T04:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SU"
    }
  }

  # Vertical Pod Autoscaling (default in Autopilot)
  vertical_pod_autoscaling {
    enabled = true
  }

  # Remove default node pool (Autopilot manages nodes)
  remove_default_node_pool = true
  initial_node_count       = 1

  # Logging and monitoring
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER"
    ]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER"
    ]
    managed_prometheus {
      enabled = true
    }
  }

  # Labels for cost attribution
  labels = {
    env        = var.environment
    managed_by = "terraform"
    project    = "platform"
  }

  # Tags for network routing
  tags = [
    "gke-${var.cluster_name}",
    "platform-${var.environment}"
  ]

  # Timeout
  timeout {
    create = "30m"
    update = "40m"
  }
}

# Workload Identity IAM bindings for service accounts
resource "google_service_account_iam_binding" "workload_identity_binding" {
  for_each           = var.workload_identity_bindings
  service_account_id = each.value.gcp_sa_id
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.k8s_sa_name}]"
  ]
}

# IAM binding for GKE node service account
resource "google_project_iam_member" "gke_node_sa" {
  project = var.project_id
  role    = "roles/container.nodeServiceAccount"
  member  = "serviceAccount:${var.project_id}.svc.id.goog[default]"
}
