# Variables for Host VM and Edge deployment
variable "admin_cidr" {
  description = "CIDR that can SSH to the Host VMs. For GCP, the IAP range is always allowed."
  default     = []
}

variable "region" {
  description = "Define the region for the VMs."
  default     = "us-central1"
}

variable "project_id" {
  description = "GCP project to deploy into."
  default     = null

  #   validation {
  #     condition     = (var.project_id != null && var.subscription_id != null) != null || (var.project_id == null && var.subscription_id == null)
  #     error_message = "You must define the GCP Project ID (project_id) OR Azure Subscription ID (subscription_id)."
  #   }
}

variable "subscription_id" {
  description = "Azure Subscription to deploy into."
  default     = null

  # validation {
  #   condition     = (var.project_id != null && var.subscription_id != null) || (var.project_id == null && var.subscription_id == null)
  #   error_message = "You must define the GCP Project ID (project_id) OR Azure Subscription ID (subscription_id)."
  # }
}

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

variable "edge_vm_asn" {
  description = "ASN for Edge instances"
  default     = 64581
}

variable "edge_lan_cidr" {
  description = "/29 or larger. The bridges on each host are connected at Layer 2 using VXLAN."
  default     = "10.40.251.0/29"
  validation {
    condition     = element(split("/", var.edge_lan_cidr), 1) <= 29
    error_message = "var.edge_mgmt_cidr must be /29 or greater."
  }
}

variable "edge_image_filename" {
  description = "Edge image filename"
  default     = "avx-edge-gateway-kvm-2022-08-31-6.8.qcow2"
}

variable "internal_cidr" {
  description = "The WAN, Mgmt, internal tunnel prefixes are computed from this block. This block is not used in routing so it doesn't have to be unique. Minimum /27."
  default     = "192.168.122.0/24"
  validation {
    condition     = element(split("/", var.internal_cidr), 1) <= 27
    error_message = "var.internal_cidr must be /27 or greater."
  }
}

variable "external_cidrs" {
  description = "List of CIDRs that the Host VM should advertise into Edge. Static routes within the host VM will direct traffic to the subnet default gw."
  default     = []
}

# Locals/computed
locals {
  pov_edge_site = "${var.pov_prefix}-edge-site"

  host_vpc_name    = "${var.pov_prefix}-vpc"
  host_subnet_name = "${var.pov_prefix}-subnet"
  host_ssh         = concat(["35.235.240.0/20"], var.admin_cidr)               #GCP IAP prefix for portal ssh
  host_allow_all   = concat([var.host_vm_cidr], var.external_cidrs)            #We allow all from the external cidrs and the host_vm_cidr itself.
  host_vm_name     = [for i in range(1, 3) : "${var.pov_prefix}-host-vm-${i}"] #2 VMs, names start at 1

  storage_name = "${var.pov_prefix}-edge-bucket"

  edge_vm_name = [for i in range(1, 3) : "${var.pov_prefix}-edge-vm-${i}"] #2 VMs, names start at 1

  #Need to carve var.edge_lan_cidr and var.internal_cidr into /29 prefixes.
  prefix_size                    = 29
  internal_cidr_bits_to_subtract = (27 - element(split("/", var.internal_cidr), 1))
  edge_lan_cidr_bits_to_subtract = (29 - element(split("/", var.edge_lan_cidr), 1))

  #Define wan/mgmt cidrs and related IPs.
  edge_wan_cidr      = [cidrsubnet(var.internal_cidr, local.internal_cidr_bits_to_subtract + 3, 0), cidrsubnet(var.internal_cidr, local.internal_cidr_bits_to_subtract + 3, 1)]
  host_wan_bridge_ip = [for cidr in local.edge_wan_cidr : cidrhost(cidr, 1)]
  edge_wan_ip        = [for cidr in local.edge_wan_cidr : cidrhost(cidr, 2)]

  edge_mgmt_cidr      = [cidrsubnet(var.internal_cidr, local.internal_cidr_bits_to_subtract + 3, 2), cidrsubnet(var.internal_cidr, local.internal_cidr_bits_to_subtract + 3, 3)]
  host_mgmt_bridge_ip = [for cidr in local.edge_mgmt_cidr : cidrhost(cidr, 1)]
  edge_mgmt_ip        = [for cidr in local.edge_mgmt_cidr : cidrhost(cidr, 2)]

  #LAN cidr is layer 2 bridged between the 2 hosts.
  edge_lan_cidr      = cidrsubnet(var.edge_lan_cidr, local.edge_lan_cidr_bits_to_subtract, 0)
  host_lan_bridge_ip = [for i in range(1, 3) : cidrhost(local.edge_lan_cidr, i)]
  edge_lan_ip        = [for i in range(3, 5) : cidrhost(local.edge_lan_cidr, i)]

  #List of CIDRs to route out to the VPC.
  external_cidrs = concat([var.host_vm_cidr], var.external_cidrs)

  host_vms = { for i, name in local.host_vm_name : name => {
    index = i

    host_vm     = name
    host_vm_asn = var.host_vm_asn
    vpc_ip      = cidrhost(var.host_vm_cidr, i + 2)

    startup_sh      = "${path.module}/${name}/startup.sh"
    wan_prefix      = local.prefix_size + 1
    wan_bridge_ip   = local.host_wan_bridge_ip[i]
    wan_xml         = "${path.module}/${name}/br-wan.xml"
    lan_prefix      = local.prefix_size,
    lan_bridge_ip   = local.host_lan_bridge_ip[i]
    lan_xml         = "${path.module}/${name}/br-lan.xml"
    mgmt_dhcp       = local.edge_mgmt_ip[i]
    mgmt_prefix     = local.prefix_size + 1
    mgmt_bridge_ip  = local.host_mgmt_bridge_ip[i]
    mgmt_xml        = "${path.module}/${name}/br-mgmt.xml"
    edge_vm         = local.edge_vm_name[i]
    edge_vm_xml     = "${path.module}/${name}/vm.xml"
    wan_edge_prefix = "${local.edge_wan_ip[i]}/${local.prefix_size + 1}",
    lan_edge_prefix = "${local.edge_lan_ip[i]}/${local.prefix_size}"
    lan_edge_ip     = local.edge_lan_ip[i]
    ztp_basename    = "${local.edge_vm_name[i]}-${local.pov_edge_site}.iso"
    ztp_iso         = "${path.module}/${name}/${local.edge_vm_name[i]}-${local.pov_edge_site}.iso"
    }
  }

  host_vxlans = { for i, my in local.host_vm_name : "${my}_vxlan_sh" => {
    network_sh   = "${path.module}/${my}/libvirt-hook-network.sh"
    my_vpc_ip    = local.host_vms[my].vpc_ip
    peer_vpc_ips = [for peer in local.host_vm_name : local.host_vms[peer].vpc_ip if my != peer]
    }
  }

  frr_confs = { for i, my in local.host_vm_name : "${my}_frr_conf" => {
    frr_conf       = "${path.module}/${my}/frr.conf"
    host_vm        = my
    external_cidrs = local.external_cidrs
    vpc_gw         = cidrhost(var.host_vm_cidr, 1)
    host_vm_asn    = var.host_vm_asn
    edge_vm_asn    = var.edge_vm_asn
    my_ip          = local.host_vms[my].lan_bridge_ip
    edge_ip        = local.host_vms[my].lan_edge_ip
    peer_ips       = [for peer in local.host_vm_name : local.host_vms[peer].lan_bridge_ip if my != peer]
  } }
}