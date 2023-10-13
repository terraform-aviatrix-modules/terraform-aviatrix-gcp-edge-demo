# gcp-edge-demo

Deploy Aviatrix Edge 2.0 in GCP (and eventually Azure.) AWS doesn't support nested virtualization, except on .metal instances.

## Software Requirements

Terraform
Google Cloud SDK/GCloud CLI: Must use **gcloud init** and **gcloud auth application-default login**.

## Other requirements

The IP of the Edge Host VMs must be allowed to connect to the controller on port 443. The example below shows GCP.

## Example

```terraform
# Provider configuration

terraform {
  required_providers {
    aviatrix = {
      source  = "aviatrixsystems/aviatrix"
      version = "~> 3.1.1"
    }
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "aviatrix" {}

provider "google" {
  project = "my-project"
  region  = "us-central1"
}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com/"
}

module "edge" {
  source                          = "terraform-aviatrix-modules/gcp-edge-demo/aviatrix"
  version                         = "3.1.1"
  admin_cidr                      = ["${chomp(data.http.myip.response_body)}/32"]
  region                          = "us-west2"
  pov_prefix                      = "us-west2-demo"
  host_vm_size                    = "n2-standard-2"
  test_vm_size                    = "n2-standard-2"
  test_vm_internet_ingress_ports  = ["443", "8443"]
  host_vm_cidr                    = "10.40.251.16/28"
  host_vm_asn                     = 64900
  host_vm_count                   = 1
  edge_vm_asn                     = 64581
  edge_lan_cidr                   = "10.40.251.0/29"
  edge_image_filename             = "${path.module}/avx-edge-kvm-7.1-2023-04-24.qcow2"
  test_vm_metadata_startup_script = null
  external_cidrs = []
  vm_ssh_key     = file("~/.ssh/id_rsa.pub")
  transit_gateways = []
}
```
