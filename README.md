# gcp-edge-demo

Deploy Aviatrix Edge GCP. AWS doesn't support nested virtualization, except on .metal instances.

## Software Requirements

Terraform
Google Cloud SDK/GCloud CLI: Must use **gcloud init** and **gcloud auth application-default login**.

## Compatibility

| Module version | Terraform version | Controller version | Terraform provider version |
| :------------- | :---------------- | :----------------- | :------------------------- |
| v3.2.1         | >= 1.5.0          | >= 7.2             | ~>3.2.0                    |
| v3.1.4         | >= 1.3.0          | >= 7.1             | ~>3.1.0                    |

## Module Attributes

### Required
  
  | key                 | value                                                                                   |
  | :------------------ | :-------------------------------------------------------------------------------------- |
  |                     |
  | source              | "terraform-aviatrix-modules/gcp-edge-demo/aviatrix"                                     |
  | version             | "3.2.1"                                                                                 |
  | edge_image_location | gcp_bucket/filename.qcow2                                                               |
  | edge_image_filename | ${path.module}/filename.qcow2                                                           |
  | vm_ssh_key          | Host/Test VM Public Key in string form. Must include user@domain at the end of the key. |

*NOTE: `edge_image_location` and `edge_image_filename` are mutually exclusive, but one is required.

### Optional

| key                             | value                                                                                                                                                     |
| :------------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------- |
| admin_cidr                      | CIDRs that can SSH to the Host VMs. For GCP, the IAP range is always allowed.                                                                             |
| region                          | Define the region for the VM and Storage Account. "us-central1" is the default                                                                            |
| pov_prefix                      | Name prefix to prepend to all created resources. Default is "avx"                                                                                         |
| host_vm_size                    | Must be capable of virtualization. Default is "n2-standard-2"                                                                                             |
| host_vm_cidr                    | /28 is minimum size. Only need 3 IPs - 2x host VM plus ILB. Default is "10.40.251.16/28"                                                                  |
| host_vm_asn                     | ASN for the host VMs. Default is "64900"                                                                                                                  |
| host_vm_count                   | Number of host VMs (and Edge VMs) to deploy. Default is "2"                                                                                               |
| test_vm_size                    | "Test VM size. Default is "e2-micro"                                                                                                                      |
| edge_vm_asn                     | ASN for Edge instances. Default is "64581"                                                                                                                |
| edge_lan_cidr                   | The bridges on each host are connected at Layer 2 using VXLAN. 2 IPs per host VM. Default is "10.40.251.0/29"                                             |
| test_vm_metadata_startup_script | Metadata startup script for the test vm. Default is `null`                                                                                                |
| external_cidrs                  | List of CIDRs that the Host VM should advertise into Edge. Static routes within the host VM will direct traffic to the subnet default gw. Default is "[]" |
| transit_gateways                | List of Transit Gateways to add edge attachments. Default is "[]"                                                                                         |

## Example

```terraform
# Provider configuration

terraform {
  required_providers {
    aviatrix = {
      source  = "aviatrixsystems/aviatrix"
      version = "~> 3.2.1"
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
  version                         = "3.2.1"
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
  edge_image_location             = "gcp_bucket/avx-gateway-avx-g3-202409102334.qcow2"
  test_vm_metadata_startup_script = null
  external_cidrs                  = []
  vm_ssh_key                      = file("~/.ssh/id_rsa.pub")
  transit_gateways                = []
}
```
