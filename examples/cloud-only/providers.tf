terraform {
  required_version = ">= 1.9.0"

  required_providers {
    nebius = {
      source  = "nebius/nebius"
      version = ">= 0.6.8"
    }
    castai = {
      source  = "castai/castai"
      version = ">= 9.6.3"
    }
  }
}

# The owner of the cloud resources authenticates to Nebius with a service
# account authorized key. A CAST AI API token is also required: Terraform
# configures the castai provider even though the module creates no CAST AI
# resources and reads no CAST AI data in this mode.
provider "castai" {
  api_token = var.castai_api_token
}

provider "nebius" {
  service_account = {
    account_id_env       = "SA_ID"
    public_key_id_env    = "AUTHKEY_PUBLIC_ID"
    private_key_file_env = "AUTHKEY_PRIVATE_PATH"
  }
}
