# Create files for Host and Edge VM deployment.
# Files are for Azure or GCP, or really any functional Libvirt deployment

resource "local_file" "libvirt_br_wan_xml" {
  for_each = local.host_vms

  content  = replace(templatefile("${path.module}/br-wan.tftpl", each.value), "/\r/", "")
  filename = "${path.root}/${each.key}/br-wan.xml"
}

resource "local_file" "libvirt_br_lan_xml" {
  for_each = local.host_vms

  content  = replace(templatefile("${path.module}/br-lan.tftpl", each.value), "/\r/", "")
  filename = "${path.root}/${each.key}/br-lan.xml"
}

resource "local_file" "libvirt_br_mgmt_xml" {
  for_each = local.host_vms

  content  = replace(templatefile("${path.module}/br-mgmt.tftpl", each.value), "/\r/", "")
  filename = "${path.root}/${each.key}/br-mgmt.xml"
}

resource "local_file" "libvirt_vm_xml" {
  for_each = local.host_vms

  content  = replace(templatefile("${path.module}/vm.tftpl", each.value), "/\r/", "")
  filename = "${path.root}/${each.key}/vm.xml"
}

resource "local_file" "startup_script" {
  for_each = local.host_vms

  content  = replace(templatefile("${path.module}/startup-sh.tftpl", each.value), "/\r/", "")
  filename = "${path.root}/${each.key}/startup.sh"
}

resource "local_file" "frr_conf" {
  for_each = local.frr_vxlan_confs

  content  = replace(templatefile("${path.module}/frr_conf.tftpl", each.value), "/\r/", "")
  filename = "${path.root}/${each.key}/frr.conf"
}

resource "local_file" "libvirt_hook_network" {
  for_each = local.frr_vxlan_confs

  content  = replace(templatefile("${path.module}/libvirt-hook-network.tftpl", each.value), "/\r/", "")
  filename = "${path.root}/${each.key}/libvirt-hook-network.sh"
}

# Get current Public IP
# data "http" "my_public_ip" {
#   url = "http://ifconfig.me"
# }