# Terraform tests for infrastructure validation

run "validate_vpc_module" {
  command = plan

  assert {
    condition     = module.vpc.vpc_id != null
    error_message = "VPC ID should not be null after plan"
  }

  assert {
    condition     = length(module.vpc.private_subnet_ids) >= 1
    error_message = "At least one private subnet should be created"
  }

  assert {
    condition     = length(module.vpc.public_subnet_ids) >= 1
    error_message = "At least one public subnet should be created"
  }
}

run "validate_gke_module" {
  command = plan

  assert {
    condition     = module.gke.cluster_name != null
    error_message = "GKE cluster name should not be null"
  }

  assert {
    condition     = module.gke.cluster_endpoint != null
    error_message = "GKE cluster endpoint should not be null"
  }
}

run "validate_cloudsql_module" {
  command = plan

  assert {
    condition     = module.cloudsql.instance_name != null
    error_message = "Cloud SQL instance name should not be null"
  }

  assert {
    condition     = module.cloudsql.private_ip != null
    error_message = "Cloud SQL should have a private IP"
  }
}

run "validate_iam_module" {
  command = plan

  assert {
    condition     = length(module.iam.service_account_emails) > 0
    error_message = "At least one service account should be created"
  }
}

run "validate_dns_module" {
  command = plan

  assert {
    condition     = module.dns.zone_name != null
    error_message = "DNS zone name should not be null"
  }
}

run "validate_no_public_ips" {
  command = plan

  assert {
    condition     = !anytrue([for r in google_compute_instance.default : r.network_interface[0].access_config != null])
    error_message = "No instances should have public IPs"
  }
}

run "validate_binary_authorization" {
  command = plan

  assert {
    condition     = module.gke.binary_authorization == true
    error_message = "Binary Authorization should be enabled on GKE"
  }
}
