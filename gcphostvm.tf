#Deploy host VM

#Create VM PIP
resource "google_compute_address" "host_vm_pip" {
  for_each = local.host_vms

  name = "${each.key}-pip"
}

#Using the default compute service account.
data "google_compute_default_service_account" "default" {}

#Availability zones
data "google_compute_zones" "available" {}

#Create the VM
resource "google_compute_instance" "host_vm" {
  for_each = local.host_vms

  name                      = each.key
  machine_type              = var.host_vm_size
  zone                      = data.google_compute_zones.available.names[each.value.index % length(data.google_compute_zones.available.names)]
  allow_stopping_for_update = true
  can_ip_forward            = true

  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]
  }

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20220902"
      size  = 100
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet.self_link
    network_ip = each.value.vpc_ip
    nic_type   = "GVNIC"
    access_config {
      nat_ip = google_compute_address.host_vm_pip[each.key].address
    }
  }

  advanced_machine_features {
    enable_nested_virtualization = true
  }

  metadata = {
    startup-script-url = "gs://${google_storage_bucket.bucket.name}/${each.key}/startup.sh"
    user-data          = replace(file("${path.module}/host-cloud-init.yaml"), "/\r/", "")
    ssh-keys           = local.host_vm_ssh_key
    edge-site-name     = local.pov_edge_site
    edge-vm-name       = each.value.edge_vm
  }

  # lifecycle {
  #   ignore_changes = [
  #     metadata["ssh-keys"]
  #   ]
  # }

  depends_on = [
    google_storage_bucket_object.libvirt_br_wan_xml,
    google_storage_bucket_object.libvirt_br_lan_xml,
    google_storage_bucket_object.libvirt_br_mgmt_xml,
    google_storage_bucket_object.libvirt_vm_xml,
    google_storage_bucket_object.libvirt_hook_network,
    google_storage_bucket_object.startup_script,
    google_storage_bucket_object.frr_conf,
    google_storage_bucket_object.qcow2,
    google_storage_bucket_object.edge_ztp
  ]
}

#Create unmanaged IGs
resource "google_compute_instance_group" "instance_group" {
  count = length(local.host_vms) < length(data.google_compute_zones.available.names) ? length(local.host_vms) : length(data.google_compute_zones.available.names)

  name    = "${local.host_vm_prefix}-${data.google_compute_zones.available.names[count.index]}"
  zone    = data.google_compute_zones.available.names[count.index]
  network = google_compute_network.vpc_network.id

  instances = [for vm in google_compute_instance.host_vm : vm.id if vm.zone == data.google_compute_zones.available.names[count.index]]
}
