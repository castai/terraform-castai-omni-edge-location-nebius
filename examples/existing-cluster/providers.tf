terraform {
  required_version = ">= 1.9.0"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 8.64.0"
    }
    nebius = {
      source  = "nebius/nebius"
      version = ">= 0.6.8"
    }
  }
}

provider "nebius" {
  service_account = {
    account_id       = var.nebius_service_account_id
    public_key_id    = var.nebius_public_key_id
    private_key_file = var.nebius_private_key_path
  }
}

provider "castai" {
  api_token = var.castai_api_token
  api_url   = var.castai_api_url
}
