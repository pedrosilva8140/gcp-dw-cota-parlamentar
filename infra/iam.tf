# Identidade do job de ingestão
resource "google_service_account" "ingestao" {
  account_id   = "ingestao-sa"
  display_name = "Ingestao da Cota Parlamentar"
}

# Pode ler e gravar arquivos SÓ neste bucket
resource "google_storage_bucket_iam_member" "ingestao_bucket" {
  bucket = google_storage_bucket.raw.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ingestao.email}"
}

# Pode criar e alterar tabelas SÓ no dataset raw
resource "google_bigquery_dataset_iam_member" "ingestao_raw" {
  dataset_id = google_bigquery_dataset.camadas["raw"].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.ingestao.email}"
}

# Pode executar jobs de carga no BigQuery
resource "google_project_iam_member" "ingestao_jobs" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.ingestao.email}"
}

# Identidade do Cloud Build (build da imagem do job a partir do código-fonte).
# Conta dedicada em vez da conta padrão do Compute, que não tem papéis no projeto.
resource "google_service_account" "build" {
  account_id   = "build-sa"
  display_name = "Build da imagem de ingestao"
}

# Pode ler o código enviado, gravar logs e publicar a imagem no Artifact Registry
resource "google_project_iam_member" "build_builder" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.build.email}"
}

output "build_service_account" {
  value = google_service_account.build.email
}

output "service_account" {
  value = google_service_account.ingestao.email
}