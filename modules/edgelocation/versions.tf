terraform {
  required_version = ">= 1.9.0"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 9.6.3"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}
