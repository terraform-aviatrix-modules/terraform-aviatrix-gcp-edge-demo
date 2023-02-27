# avxedgedemo
Deploy Aviatrix Edge 2.0 in GCP (and eventually Azure.) AWS doesn't support nested virtualization, except on .metal instances.

# Software Requirements
Terraform
Google Cloud SDK/GCloud CLI: Must use **gcloud init** and **gcloud auth application-default login**.

# Other requirements
The IP of the Edge Host VMs must be allowed to connect to the controller on port 443. The example below shows GCP.

# Example
```
# Provider configuration

terraform {
  required_providers {
    aviatrix = {
      source  = "aviatrixsystems/aviatrix"
      #version = "~>2.24.0"
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

module "avxedgedemo" {
  source = "github.com/MatthewKazmar/avxedgedemo"

  admin_cidr = ["1.2.3.4/32"]
  pov_prefix = "avx-mattk"
  host_vm_size = "n2-standard-2"
  host_vm_cidr = "10.40.251.16/28"
  host_vm_asn = "64900"
  host_vm_count = 2
  test_vm_size = "e2-micro"
  vm_ssh_key = "" # Optional: Additional VM public keys
  edge_vm_asn = 64581
  edge_lan_cidr = "10.40.251.0/29"
  edge_image_filename = "" # Edge image/path
  external_cidrs = [] # FRR will routes these cidrs to the GCP default GW
  transit_gateways = [ "transit-gcp-1", "transit-aws-2" ]
}

resource "google_compute_firewall" "avx-edge" {
  name = "avx-edge-pips"
  network = "avx-mgmt" # Put in the name of your Aviatrix management network here.

  allow {
    protocol = "tcp"
    ports = [ "443" ]
  }

  direction = "INGRESS"
  source_ranges = [ for pip in module.avxedgedemo.host_vm_pip: pip.address ]
  target_tags = ["aviatrix-sec-mgmt"]
}

output "public_ips" {
  value = merge(
    { for k, v in module.avxedgedemo.host_vm_pip : v.name => v.address },
    { "${module.avxedgedemo.test_vm_pip.name}" = module.avxedgedemo.test_vm_pip.address }
  )
}

```
