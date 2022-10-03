# avxedgedemo
Deploy Aviatrix Edge 2.0 in GCP (and eventually Azure.) AWS doesn't support nested virtualization, except on .metal instances.

# Example
```
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
  transit_gateways = [ "transit-gcp-1", "transit-gcp-2" ]
}
```
