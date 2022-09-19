# Provider configuration

terraform {
  required_providers {
    aviatrix = {
      source  = "aviatrixsystems/aviatrix"
      version = "~>2.24.0"
    }
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "aviatrix" {}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_compute_zones" "available" {}