terraform {
  required_providers {
    aviatrix = {
      source  = "aviatrixsystems/aviatrix"
      version = ">= 3.2.0"
    }
    google = {
      source = "hashicorp/google"
    }
  }
}
