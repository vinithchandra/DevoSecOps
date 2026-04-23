output "dataset_ids" {
  description = "Map of created dataset IDs"
  value = merge(
    { "research" = google_bigquery_dataset.research.dataset_id },
    { for k, v in google_bigquery_dataset.experiment_datasets : k => v.dataset_id }
  )
}

output "table_ids" {
  description = "Map of created table IDs"
  value = { for k, v in google_bigquery_table.experiment_tables : k => v.id }
}
