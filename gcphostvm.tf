# Deploy the VPC/subnet and the host VMs.
# Copies necessary files to the VM via Storage Bucket intermediary.

# Create VPC and Firewall
resource "google_compute_network" "vpc_network" {
  name                    = local.host_vpc_name
  mtu                     = 1600 #VXLAN between host VMs
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vpc_subnet" {
  name          = local.host_subnet_name
  ip_cidr_range = var.host_vm_cidr
  network       = google_compute_network.vpc_network.name
}

resource "google_compute_firewall" "ssh" {
  name    = "${local.host_vpc_name}-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = local.host_ssh
}

resource "google_compute_firewall" "allow_all" {
  name    = "${local.host_vpc_name}-allow-all"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "all"
  }

  source_ranges = local.host_allow_all
}

resource "google_compute_firewall" "allow_egress" {
  name    = "${local.host_vpc_name}-allow-egress"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "all"
  }

  direction          = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]
}

#Create VM PIP and VM itself.
resource "google_compute_address" "host_vm_pip" {
  for_each = local.host_vms

  name = "${each.key}-pip"
}

data "google_compute_default_service_account" "default" {}

resource "google_compute_instance" "host_vm" {
  for_each = local.host_vms

  name                      = each.key
  machine_type              = var.host_vm_size
  zone                      = data.google_compute_zones.available.names[each.value.index] #This is dumb and will break when we run out of Zones, but 2 is fine for now.
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
  }

  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"]
    ]
  }

  depends_on = [
    google_storage_bucket_object.startup_script
  ]
}

# Create Storage Bucket and upload the files.
# By default, Public access is not allowed. (Good).
# The creating account is the owner.
# The Project Owners/Editors have read/right.
# The Compute Engine default as well as a few other accounts have read access.
# This default is fine for this deployment.
resource "google_storage_bucket" "bucket" {
  name     = local.storage_name
  location = var.region

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "libvirt_br_wan_xml" {
  for_each = local_file.libvirt_br_wan_xml

  name   = trimprefix(each.value.filename, "./")
  source = each.value.filename
  bucket = google_storage_bucket.bucket.name

  lifecycle {
    replace_triggered_by = [
      local_file.libvirt_br_wan_xml
    ]
  }
}

resource "google_storage_bucket_object" "libvirt_br_lan_xml" {
  for_each = local_file.libvirt_br_lan_xml

  name   = trimprefix(each.value.filename, "./")
  source = each.value.filename
  bucket = google_storage_bucket.bucket.name

  lifecycle {
    replace_triggered_by = [
      local_file.libvirt_br_lan_xml
    ]
  }
}

resource "google_storage_bucket_object" "libvirt_br_mgmt_xml" {
  for_each = local_file.libvirt_br_mgmt_xml

  name   = trimprefix(each.value.filename, "./")
  source = each.value.filename
  bucket = google_storage_bucket.bucket.name

  lifecycle {
    replace_triggered_by = [
      local_file.libvirt_br_mgmt_xml
    ]
  }
}

resource "google_storage_bucket_object" "libvirt_vm_xml" {
  for_each = local_file.libvirt_vm_xml

  name   = trimprefix(each.value.filename, "./")
  source = each.value.filename
  bucket = google_storage_bucket.bucket.name

  lifecycle {
    replace_triggered_by = [
      local_file.libvirt_vm_xml
    ]
  }
}

resource "google_storage_bucket_object" "libvirt_hook_network" {
  for_each = local_file.libvirt_hook_network

  name   = trimprefix(each.value.filename, "./")
  source = each.value.filename
  bucket = google_storage_bucket.bucket.name

  lifecycle {
    replace_triggered_by = [
      local_file.libvirt_hook_network
    ]
  }
}

resource "google_storage_bucket_object" "startup_script" {
  for_each = local_file.startup_script

  name   = trimprefix(each.value.filename, "./")
  source = each.value.filename
  bucket = google_storage_bucket.bucket.name

  lifecycle {
    replace_triggered_by = [
      local_file.startup_script
    ]
  }
}

resource "google_storage_bucket_object" "frr_conf" {
  for_each = local_file.frr_conf

  name   = trimprefix(each.value.filename, "./")
  source = each.value.filename
  bucket = google_storage_bucket.bucket.name

  lifecycle {
    replace_triggered_by = [
      local_file.frr_conf
    ]
  }
}

resource "google_storage_bucket_object" "qcow2" {
  name   = "edge.qcow2"
  source = var.edge_image_filename
  bucket = google_storage_bucket.bucket.name
}

resource "google_storage_bucket_object" "edge_ztp" {
  for_each = local.host_vms

  name   = trimprefix(each.value.ztp_iso, "./")
  source = each.value.ztp_iso
  bucket = google_storage_bucket.bucket.name

  lifecycle {
    replace_triggered_by = [
      aviatrix_edge_spoke.edge
    ]
  }

  depends_on = [
    aviatrix_edge_spoke.edge
  ]
}