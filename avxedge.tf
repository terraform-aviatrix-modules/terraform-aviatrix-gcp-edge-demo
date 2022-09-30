# Deploy Avx Edge Gateways in Controller, download ZTP.

resource "aviatrix_edge_spoke" "edge" {
  for_each = local.host_vms

  gw_name = each.value.edge_vm
  site_id = local.pov_edge_site

  management_interface_config = "DHCP"

  wan_interface_ip_prefix = "${each.value.wan_edge_ip}/${each.value.wan_prefix_size}"
  wan_default_gateway_ip  = each.value.wan_bridge_ip
  wan_public_ip           = google_compute_address.host_vm_pip[each.key].address

  lan_interface_ip_prefix = "${each.value.lan_edge_ip}/${each.value.lan_prefix_size}"

  ztp_file_type          = "iso"
  ztp_file_download_path = "${path.root}/${each.key}/"

  local_as_number = var.edge_vm_asn

  provisioner "local-exec" {
    when = destroy
    command = "rm ${path.root}/${each.key}/${each.value.edge_vm}-${local.pov_edge_site}.iso"
  }
}

# Connect Edge VMs to host VMs with BGPoLAN
resource "aviatrix_edge_spoke_external_device_conn" "to_host_vm" {
  for_each = local.host_vms

  site_id           = local.pov_edge_site
  connection_name   = "${each.value.edge_vm}-to-${each.key}"
  gw_name           = each.value.edge_vm
  bgp_local_as_num  = var.edge_vm_asn
  bgp_remote_as_num = var.host_vm_asn
  local_lan_ip      = each.value.lan_edge_ip
  remote_lan_ip     = each.value.lan_bridge_ip

  depends_on = [
    google_compute_instance.host_vm,
    null_resource.edge_check
  ]
}

#Connect Edge VMs to Transit
resource "aviatrix_edge_spoke_transit_attachment" "to_transit_gw" {
  for_each = local.edge_to_transit_gateways

  spoke_gw_name   = element(split(each.key, "~"), 0)
  transit_gw_name = element(split(each.key, "~"), 1)

  depends_on = [
    google_compute_instance.host_vm,
    null_resource.edge_check
  ]
}


#Validate if Edge VM is runninng
resource "null_resource" "edge_check" {
  for_each = google_compute_address.host_vm_pip

  connection {
    type        = "ssh"
    user        = "root"
    private_key = tls_private_key.root_ssh.private_key_openssh
    host        = each.value.address
  }

  provisioner "remote-exec" {
    inline = [
      "gsutil cp gs://${google_storage_bucket.bucket.name}/${google_storage_bucket_object.edge_check.name} /usr/local/bin/edge-check.py",
      "cloud-init status --wait",
      "python3 /usr/local/bin/edge-check.py"
    ]
  }

  depends_on = [
    google_compute_instance.host_vm,
    google_storage_bucket_object.edge_check
  ]
}