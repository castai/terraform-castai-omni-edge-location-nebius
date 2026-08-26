terraform {
  required_version = ">= 1.9.0"

  required_providers {
    castai = {
      source = "castai/castai"
      # NOTE: Nebius support in the castai provider is assumed for this draft.
      # Bump to the version that introduces the `nebius` block on
      # castai_edge_location / castai_edge_configuration once available.
      version = ">= 8.64.0"
    }
    nebius = {
      source  = "nebius/nebius"
      version = ">= 0.6.8"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.0"
    }
  }
}
