terraform {
  required_version = ">= 1.9.0"

  required_providers {
    nebius = {
      source  = "nebius/nebius"
      version = ">= 0.6.8"
    }
  }
}

# Cloud-resources-only mode needs only the Nebius provider: the cloud submodule
# contains no CAST AI resources or data sources, so no CAST AI credentials are
# required for this run.
provider "nebius" {
  service_account = {
    account_id       = var.nebius_service_account_id
    public_key_id    = var.nebius_public_key_id
    private_key_file = var.nebius_private_key_path
  }
}
