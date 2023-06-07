# Provider configuration

terraform {
  required_providers {
    aviatrix = {
      source  = "aviatrixsystems/aviatrix"
      version = ">= 3.1.0"
    }
    google = {
      source = "hashicorp/google"
    }
  }
}
