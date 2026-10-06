terraform {
  required_version = ">= 1.9.0"

  required_providers {
    nebius = {
      source  = "registry.terraform.io/nebius/nebius"
      version = ">= 0.6.8"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.0"
    }
  }
}
