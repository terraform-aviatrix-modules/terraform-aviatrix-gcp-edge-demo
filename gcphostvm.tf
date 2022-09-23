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

locals {

}

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
      nat_ip = resource.google_compute_address.host_vm_pip[each.key].address
    }
  }

  advanced_machine_features {
    enable_nested_virtualization = true
  }

  metadata = {
    startup-script-url = "gs://${google_storage_bucket.bucket.name}/${each.key}/startup.sh"
    user-data          = file("${path.module}/cloud-init.yaml")
    nested-vm-status   = "na"
  }

  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"]
    ]
  }

  depends_on = [
    google_storage_bucket_object.startup_script,
    google_storage_bucket_object.qcow2
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