terraform {
  required_version = ">= 1.9.0"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 9.6.3"
    }
  }
}

# The owner of the edge location authenticates to CAST AI with an API token.
# No Nebius provider configuration is needed in this mode: the module creates
# no Nebius resources and reads no Nebius data sources when provision_cloud
# is false.
provider "castai" {
  api_token = var.castai_api_token
  api_url   = var.castai_api_url
}
