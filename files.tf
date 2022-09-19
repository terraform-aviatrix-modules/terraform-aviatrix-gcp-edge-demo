# Create Libvirt XML files for Edge deployment

resource "local_file" "libvirt_br_wan_xml" {
  for_each = local.host_vms

  content  = templatefile("br-wan.tftpl", each.value)
  filename = each.value.wan_xml
}

resource "local_file" "libvirt_br_lan_xml" {
  for_each = local.host_vms

  content  = templatefile("br-lan.tftpl", each.value)
  filename = each.value.lan_xml
}

resource "local_file" "libvirt_br_mgmt_xml" {
  for_each = local.host_vms

  content  = templatefile("br-mgmt.tftpl", each.value)
  filename = each.value.mgmt_xml
}

resource "local_file" "libvirt_vm_xml" {
  for_each = local.host_vms

  content  = templatefile("vm.tftpl", each.value)
  filename = each.value.edge_vm_xml
}

resource "local_file" "libvirt_hook_network" {
  for_each = local.host_vxlans

  content  = templatefile("libvirt-hook-network.tftpl", each.value)
  filename = each.value.network_sh
}

resource "local_file" "startup_script" {
  for_each = local.host_vms

  content  = templatefile("startup-sh.tftpl", merge(each.value, { bucket = google_storage_bucket.bucket.name }))
  filename = each.value.startup_sh
}

resource "local_file" "frr_conf" {
  for_each = local.frr_confs

  content  = templatefile("frr_conf.tftpl", each.value)
  filename = each.value.frr_conf
}