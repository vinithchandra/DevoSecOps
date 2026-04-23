variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "table_expiration_ms" {
  description = "Default table expiration in milliseconds (0 = never)"
  type        = string
  default     = "0"
}

variable "experiment_datasets" {
  description = "Map of experiment datasets to create"
  type = map(object({
    friendly_name = string
    description   = string
  }))
  default = {
    experiment1_security_ablation = {
      friendly_name = "Security Layer Ablation"
      description   = "Experiment 1: Security layer ablation study data"
    }
    experiment2_automation_mttr = {
      friendly_name = "Automation MTTR"
      description   = "Experiment 2: Automation impact on MTTR"
    }
    experiment3_chaos_slo_calibration = {
      friendly_name = "Chaos SLO Calibration"
      description   = "Experiment 3: Chaos engineering for SLO threshold calibration"
    }
    experiment4_ci_gate_effectiveness = {
      friendly_name = "CI Gate Effectiveness"
      description   = "Experiment 4: CI pipeline gate effectiveness and cost"
    }
    experiment5_tenant_isolation = {
      friendly_name = "Tenant Isolation"
      description   = "Experiment 5: Tenant isolation blast radius measurement"
    }
  }
}

variable "tables" {
  description = "Map of tables to create with schema file paths"
  type = map(object({
    dataset_id     = string
    friendly_name  = string
    description    = string
    schema_file    = string
  }))
  default = {}
}

variable "service_account_editors" {
  description = "Map of service accounts to grant BigQuery Data Editor access"
  type        = map(list(string))
  default     = {}
}
