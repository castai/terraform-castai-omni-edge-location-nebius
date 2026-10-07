terraform {
  required_version = ">= 1.9.0"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 9.6.3"
    }
    nebius = {
      source  = "registry.terraform.io/nebius/nebius"
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
