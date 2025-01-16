# Deploy Avx Edge Gateways in Controller, download ZTP.

resource "aviatrix_edge_gateway_selfmanaged" "edge" {
  for_each = local.host_vms

  gw_name                          = each.value.edge_vm
  site_id                          = local.pov_edge_site
  ztp_file_type                    = "iso"
  ztp_file_download_path           = "${path.root}/${each.key}/"
  management_egress_ip_prefix_list = [format("%s/%s", google_compute_address.host_vm_pip[each.key].address, "32")]


  local_as_number = var.edge_vm_asn

  interfaces {
    name          = "eth0"
    type          = "WAN"
    ip_address    = "${each.value.wan_edge_ip}/${each.value.wan_prefix_size}"
    gateway_ip    = each.value.wan_bridge_ip
    wan_public_ip = google_compute_address.host_vm_pip[each.key].address
  }

  interfaces {
    name       = "eth1"
    type       = "LAN"
    ip_address = "${each.value.lan_edge_ip}/${each.value.lan_prefix_size}"
  }

  interfaces {
    name        = "eth2"
    type        = "MANAGEMENT"
    enable_dhcp = true
  }

  provisioner "local-exec" {
    when       = destroy
    command    = "rm ${self.ztp_file_download_path}${self.gw_name}-${self.site_id}.iso"
    on_failure = continue
  }

  provisioner "local-exec" {
    when       = destroy
    command    = "del ${self.ztp_file_download_path}${self.gw_name}-${self.site_id}.iso"
    on_failure = continue
  }
}

# Connect Edge VMs to host VMs with BGPoLAN
resource "aviatrix_edge_spoke_external_device_conn" "to_host_vm" {
  for_each = { for k, v in local.host_vms : k => v if var.connect_host_bgp }

  site_id           = local.pov_edge_site
  connection_name   = "${each.value.edge_vm}-to-${each.key}"
  gw_name           = each.value.edge_vm
  bgp_local_as_num  = var.edge_vm_asn
  bgp_remote_as_num = var.host_vm_asn
  local_lan_ip      = each.value.lan_edge_ip
  remote_lan_ip     = each.value.lan_bridge_ip
  number_of_retries = var.number_of_retries
  retry_interval    = var.retry_interval

  depends_on = [
    google_compute_instance.host_vm,
    aviatrix_edge_gateway_selfmanaged.edge
  ]
}

#Connect Edge VMs to Transit
resource "aviatrix_edge_spoke_transit_attachment" "to_transit_gw" {
  for_each = local.edge_to_transit_gateways

  spoke_gw_name               = element(split("~", each.key), 0)
  transit_gw_name             = element(split("~", each.key), 1)
  enable_over_private_network = false
  number_of_retries           = 2
  edge_wan_interfaces         = ["eth0"]
  spoke_prepend_as_path       = []
  transit_prepend_as_path     = []
  enable_insane_mode          = var.enable_hpe_spoke
  insane_mode_tunnel_number   = var.enable_hpe_spoke ? var.hpe_tunnel_number : null

  depends_on = [
    google_compute_instance.host_vm,
    aviatrix_edge_gateway_selfmanaged.edge,
    aviatrix_edge_spoke_external_device_conn.to_host_vm
  ]
}
