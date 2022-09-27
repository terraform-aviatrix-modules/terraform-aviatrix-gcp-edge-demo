# Variables for Host VM and Edge deployment
variable "admin_cidr" {
  description = "CIDRs that can SSH to the Host VMs. For GCP, the IAP range is always allowed."
  default     = []
}

variable "region" {
  description = "Define the region for the VM and Storage Account."
  default     = "us-central1"
}

# variable "project_id" {
#   description = "GCP project to deploy into."
#   default     = null

#   #   validation {
#   #     condition     = (var.project_id != null && var.subscription_id != null) != null || (var.project_id == null && var.subscription_id == null)
#   #     error_message = "You must define the GCP Project ID (project_id) OR Azure Subscription ID (subscription_id)."
#   #   }
# }

# variable "subscription_id" {
#   description = "Azure Subscription to deploy into."
#   default     = null

#   # validation {
#   #   condition     = (var.project_id != null && var.subscription_id != null) || (var.project_id == null && var.subscription_id == null)
#   #   error_message = "You must define the GCP Project ID (project_id) OR Azure Subscription ID (subscription_id)."
#   # }
# }

variable "pov_prefix" {
  description = "Name prefix to prepend to all created resources. ie avx-edge-vm-1."
  default     = "avx"
}

# variable "host_vm_number" {
#   description = "If multiple host VMs are deployed from the calling Plan, append this number to the VM name."
#   default     = 1
# }

variable "host_vm_size" {
  description = "Has to be capable of virtualization."
  default     = "n2-standard-2"
}

variable "host_vm_cidr" {
  description = "/28 is minimum size. Only need 3 IPs - 2x host VM plus ILB."
  default     = "10.40.251.16/28"
}

variable "host_vm_asn" {
  description = "ASN for host VMs"
  default     = 64900
}

variable "host_vm_count" {
  description = "Number of host VMs (and Edge VMs) to deploy."
  default     = 2
}

variable "test_vm_size" {
  description = "Test VM. Itty bitty is fine."
  default     = "e2-micro"
}

variable "vm_ssh_key" {
  description = "Host/Test VM Public Key in string form. Must include user@domain at the end of the key."
  default     = ""
}

variable "edge_vm_asn" {
  description = "ASN for Edge instances"
  default     = 64581
}

variable "edge_lan_cidr" {
  description = "The bridges on each host are connected at Layer 2 using VXLAN. 2 IPs per host VM."
  default     = "10.40.251.0/29"
}

variable "edge_image_filename" {
  description = "Edge image filename"
  default     = "avx-edge-gateway-kvm-2022-08-31-6.8.qcow2"
}

variable "external_cidrs" {
  description = "List of CIDRs that the Host VM should advertise into Edge. Static routes within the host VM will direct traffic to the subnet default gw."
  default     = []
}

variable "transit_gateways" {
  description = "List of Transit Gateways to connect the Edge Gateways to."
  default     = []
}

# Locals/computed
locals {
  pov_edge_site = "${var.pov_prefix}-edge-site"

  host_vpc_name    = "${var.pov_prefix}-vpc"
  host_subnet_name = "${var.pov_prefix}-subnet"
  host_ssh         = concat(["35.235.240.0/20"], var.admin_cidr) #GCP IAP prefix for portal ssh
  #host_ssh         = concat(["35.235.240.0/20", data.http.my_public_ip.response_body ], var.admin_cidr)  #GCP IAP prefix for portal ssh
  host_allow_all = concat([var.host_vm_cidr, "130.211.0.0/22", "35.191.0.0/16"], var.external_cidrs) #We allow all from the external cidrs and the host_vm_cidr itself.
  host_vm_prefix = "${var.pov_prefix}-host"

  test_vm_name = "${var.pov_prefix}-test-vm"

  vm_ssh_key = var.vm_ssh_key == "" ? "" : "${regex("([[:alnum:]]*)@", var.vm_ssh_key)[0]}:${var.vm_ssh_key}"

  edge_vm_prefix = "${var.pov_prefix}-edge"

  storage_name         = "${var.pov_prefix}-edge-bucket"
  backend_service_name = "${var.pov_prefix}-backend-service"
  hc_name              = "${var.pov_prefix}-edge-bgp-hc"
  forwarding_rule_name = "${var.pov_prefix}-edge-forwarding-rule"

  #Need to carve var.edge_lan_cidr and local.internal_cidr into /29 prefixes.
  internal_cidr = "169.254.0.0/16"

  wan_cidr                  = cidrsubnet(local.internal_cidr, 1, 0)
  wan_prefix_size           = 30 #Same as Mgmt.
  wan_cidr_bits_to_subtract = (local.wan_prefix_size - element(split("/", local.wan_cidr), 1))

  lan_prefix_size = element(split("/", var.edge_lan_cidr), 1)

  mgmt_cidr                  = cidrsubnet(local.internal_cidr, 1, 1)
  mgmt_prefix_size           = 30 #The bridge only needs the host VM and edge VM. So 2.
  mgmt_cidr_bits_to_subtract = (local.mgmt_prefix_size - element(split("/", local.mgmt_cidr), 1))

  host_vm_cidr_bits = (32 - element(split("/", var.host_vm_cidr), 1))
  #List of CIDRs to route out to the VPC.
  external_cidrs = concat([var.host_vm_cidr], var.external_cidrs)

  #Load Balancer & test vm VPC IP
  ilb_vpc_ip     = cidrhost(var.host_vm_cidr, 2)                                   #Get first usable IP
  test_vm_vpc_ip = cidrhost(var.host_vm_cidr, pow(2, local.host_vm_cidr_bits) - 3) #Get 2nd to last usable IP

  host_vms = { for i in range(var.host_vm_count) : "${var.pov_prefix}-host-vm-${i + 1}" => {
    index = i

    host_vm = "${var.pov_prefix}-host-vm-${i + 1}"
    host_asn = var.host_vm_asn
    #host_vm_asn = var.host_vm_asn
    vpc_ip = cidrhost(var.host_vm_cidr, i + 3) #Right after the ILB

    bucket = google_storage_bucket.bucket.name

    wan_prefix_size = local.wan_prefix_size
    wan_bridge_ip   = cidrhost(cidrsubnet(local.wan_cidr, local.wan_cidr_bits_to_subtract, i), 1)
    wan_edge_ip     = cidrhost(cidrsubnet(local.wan_cidr, local.wan_cidr_bits_to_subtract, i), 2)

    lan_prefix_size = local.lan_prefix_size,
    lan_bridge_ip   = cidrhost(var.edge_lan_cidr, (i * 2) + 1) #If this errors, the edge_lan_cidr prefix is too low.
    lan_edge_ip     = cidrhost(var.edge_lan_cidr, (i * 2) + 2) #If this errors, the edge_lan_cidr prefix is too low.

    mgmt_prefix_size = local.mgmt_prefix_size
    mgmt_bridge_ip   = cidrhost(cidrsubnet(local.mgmt_cidr, local.mgmt_cidr_bits_to_subtract, i), 1)
    mgmt_dhcp_ip     = cidrhost(cidrsubnet(local.mgmt_cidr, local.mgmt_cidr_bits_to_subtract, i), 2)
    mgmt_xml         = "br-mgmt.xml"

    edge_vm = "${var.pov_prefix}-edge-vm-${i + 1}"
    }
  }

  frr_vxlan_confs = { for my_name, my_obj in local.host_vms : my_name => {
    host_vm        = my_name
    external_cidrs = local.external_cidrs
    vpc_gw         = cidrhost(var.host_vm_cidr, 1)
    my_vpc_ip      = my_obj.vpc_ip
    peer_vpc_ips   = [for peer_name, peer_obj in local.host_vms : peer_obj.vpc_ip if my_obj.vpc_ip != peer_obj.vpc_ip]
    host_vm_asn    = var.host_vm_asn
    edge_vm_asn    = var.edge_vm_asn
    my_ip          = my_obj.lan_bridge_ip
    edge_ip        = my_obj.lan_edge_ip
    peer_ips       = [for peer_name, peer_obj in local.host_vms : peer_obj.lan_bridge_ip if my_obj.lan_bridge_ip != peer_obj.lan_bridge_ip]
  } }

  edge_to_transit_gateways = toset(flatten([for edge in aviatrix_edge_spoke.edge : [for transit in var.transit_gateways : "${edge}~${transit}"]]))
}