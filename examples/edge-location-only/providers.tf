terraform {
  required_version = ">= 1.9.0"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 9.6.3"
    }
  }
}

# Edge-location-only mode needs only the CAST AI provider: the edgelocation
# submodule contains no Nebius resources or data sources, so no Nebius
# credentials are required for this run.
provider "castai" {
  api_token = var.castai_api_token
  api_url   = var.castai_api_url
}
