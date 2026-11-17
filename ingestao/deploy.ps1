# Reconstroi a imagem da ingestao e atualiza o Cloud Run Job.
# Uso, a partir da raiz do repositorio:  .\ingestao\deploy.ps1
# Pre-requisito: gcloud autenticado (gcloud auth login).

$Projeto = "portfolio-de-pedro"
$Regiao  = "us-central1"
$Job     = "ingestao-cota"
$Imagem  = "$Regiao-docker.pkg.dev/$Projeto/cloud-run-source-deploy/${Job}:latest"
$BuildSA = "projects/$Projeto/serviceAccounts/build-sa@$Projeto.iam.gserviceaccount.com"
$JobSA   = "ingestao-sa@$Projeto.iam.gserviceaccount.com"

# 1. Build da imagem no Cloud Build, com a service account dedicada (build-sa)
gcloud builds submit $PSScriptRoot `
  --project $Projeto `
  --region $Regiao `
  --tag $Imagem `
  --service-account $BuildSA `
  --default-buckets-behavior regional-user-owned-bucket
if ($LASTEXITCODE -ne 0) { throw "Falha no build da imagem" }

# 2. Cria ou atualiza o job com a configuracao completa (idempotente)
gcloud run jobs deploy $Job `
  --project $Projeto `
  --region $Regiao `
  --image $Imagem `
  --service-account $JobSA `
  --set-env-vars "GOOGLE_CLOUD_PROJECT=$Projeto" `
  --cpu 1 `
  --memory 1Gi `
  --tasks 1 `
  --max-retries 1 `
  --task-timeout 1800s `
  --execution-environment gen2 `
  --labels "projeto=gcp-dw-cota-parlamentar"
if ($LASTEXITCODE -ne 0) { throw "Falha no deploy do job" }

Write-Host "Deploy concluido: $Job -> $Imagem"