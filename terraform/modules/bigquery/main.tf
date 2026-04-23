# Terraform BigQuery Module
# Creates BigQuery datasets and tables for research data collection

resource "google_bigquery_dataset" "research" {
  dataset_id    = "research"
  project       = var.project_id
  location      = "US"
  friendly_name = "Research Data Collection"
  description   = "Central dataset for DevSecOps research experiments"

  default_table_expiration = var.table_expiration_ms

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "google_bigquery_dataset" "experiment_datasets" {
  for_each = var.experiment_datasets

  dataset_id    = each.key
  project       = var.project_id
  location      = "US"
  friendly_name = each.value.friendly_name
  description   = each.value.description

  default_table_expiration = var.table_expiration_ms

  labels = {
    environment = var.environment
    experiment  = each.key
    managed_by  = "terraform"
  }
}

resource "google_bigquery_table" "experiment_tables" {
  for_each = var.tables

  dataset_id    = each.value.dataset_id
  table_id      = each.key
  project       = var.project_id
  friendly_name = each.value.friendly_name
  description   = each.value.description

  schema = file(each.value.schema_file)

  labels = {
    environment = var.environment
    experiment  = each.value.dataset_id
    managed_by  = "terraform"
  }

  depends_on = [google_bigquery_dataset.experiment_datasets]
}

resource "google_bigquery_dataset_iam_binding" "editor" {
  for_each = var.service_account_editors

  dataset_id = google_bigquery_dataset.research.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataEditor"
  members    = each.value
}
