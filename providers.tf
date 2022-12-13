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

# provider "aviatrix" {}

# provider "google" {
#   project = "lexical-period-304315"
#   region  = "us-central1"
# }