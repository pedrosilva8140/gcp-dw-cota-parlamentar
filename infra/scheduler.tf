# Identidade do agendador: só pode disparar o job de ingestão
resource "google_service_account" "scheduler" {
  account_id   = "scheduler-sa"
  display_name = "Agendador da ingestao diaria"
}

# Permissão de executar SÓ o job ingestao-cota (criado pelo gcloud run jobs deploy)
resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  name     = "ingestao-cota"
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

# Todo dia às 9h (horário de Brasília), chama a API do Cloud Run para executar o job
resource "google_cloud_scheduler_job" "ingestao_diaria" {
  name             = "ingestao-cota-diaria"
  region           = var.region
  schedule         = "0 9 * * *"
  time_zone        = "America/Sao_Paulo"
  attempt_deadline = "180s"

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/ingestao-cota:run"

    oauth_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
}
