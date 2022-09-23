# Create Libvirt XML files for Edge deployment

resource "local_file" "libvirt_br_wan_xml" {
  for_each = local.host_vms

  content  = templatefile("br-wan.tftpl", each.value)
  filename = "${path.module}/${each.key}/br-wan.xml"
}

resource "local_file" "libvirt_br_lan_xml" {
  for_each = local.host_vms

  content  = templatefile("br-lan.tftpl", each.value)
  filename = "${path.module}/${each.key}/br-lan.xml"
}

resource "local_file" "libvirt_br_mgmt_xml" {
  for_each = local.host_vms

  content  = templatefile("br-mgmt.tftpl", each.value)
  filename = "${path.module}/${each.key}/br-mgmt.xml"
}

resource "local_file" "libvirt_vm_xml" {
  for_each = local.host_vms

  content  = templatefile("vm.tftpl", each.value)
  filename = "${path.module}/${each.key}/vm.xml"
}

resource "local_file" "startup_script" {
  for_each = local.host_vms

  content  = templatefile("startup-sh.tftpl", each.value)
  filename = "${path.module}/${each.key}/startup.sh"
}

resource "local_file" "frr_conf" {
  for_each = local.frr_vxlan_confs

  content  = templatefile("frr_conf.tftpl", each.value)
  filename = "${path.module}/${each.key}/frr.conf"
}

resource "local_file" "libvirt_hook_network" {
  for_each = local.frr_vxlan_confs

  content  = templatefile("libvirt-hook-network.tftpl", each.value)
  filename = "${path.module}/${each.key}/libvirt-hook-network.sh"
}