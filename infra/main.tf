terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 7.0" }
  }
}

variable "project_id" {
  default = "portfolio-de-pedro"
}

variable "region" {
  default = "us-central1"
}

provider "google" {
  project = var.project_id
  region  = var.region
  # Etiqueta aplicada aos recursos que aceitam labels
  default_labels = {
    projeto = "gcp-dw-cota-parlamentar"
  }
}