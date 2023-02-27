# Provider configuration

terraform {
  required_providers {
    aviatrix = {
      source  = "aviatrixsystems/aviatrix"
      version = ">= 2.24.0"
    }
    google = {
      source = "hashicorp/google"
    }
  }
}
