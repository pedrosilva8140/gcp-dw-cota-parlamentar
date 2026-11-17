# Bucket dos arquivos brutos (CSV de cada ano)
resource "google_storage_bucket" "raw" {
  name                        = "${var.project_id}-cota-raw"
  location                    = upper(var.region)
  force_destroy               = true # permite destroy com arquivos dentro
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced" # nunca público
}

# Um dataset por camada do warehouse
resource "google_bigquery_dataset" "camadas" {
  for_each                   = toset(["raw", "staging", "snapshots", "marts"])
  dataset_id                 = each.value
  location                   = "US"
  delete_contents_on_destroy = true
}

output "bucket" {
  value = google_storage_bucket.raw.name
}