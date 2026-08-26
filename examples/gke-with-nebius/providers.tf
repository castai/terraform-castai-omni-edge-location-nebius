terraform {
  required_version = ">= 1.0"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 8.64.0"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
    nebius = {
      source  = "nebius/nebius"
      version = ">= 0.6.8"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }
}

provider "google" {
  project = var.gke_project_id
}

provider "nebius" {
  service_account = {
    account_id       = var.nebius_service_account_id
    public_key_id    = var.nebius_public_key_id
    private_key_file = var.nebius_private_key_path
  }
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes = {
    host                   = "https://${data.google_container_cluster.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  }
}

provider "castai" {
  api_token = var.castai_api_token
  api_url   = var.castai_api_url
}
