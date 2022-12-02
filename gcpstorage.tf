# Create Storage Bucket and upload the files.
# By default, Public access is not allowed. (Good).
# The creating account is the owner.
# The Project Owners/Editors have read/write.
# The Compute Engine default as well as a few other accounts have read access.
# This default is fine for this deployment.
resource "google_storage_bucket" "bucket" {
  name     = local.storage_name
  location = var.region

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "libvirt_br_wan_xml" {
  for_each = local_file.libvirt_br_wan_xml

  name   = "${each.key}/${basename(each.value.filename)}"
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

  name   = "${each.key}/${basename(each.value.filename)}"
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

  name   = "${each.key}/${basename(each.value.filename)}"
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

  name   = "${each.key}/${basename(each.value.filename)}"
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

  name   = "${each.key}/${basename(each.value.filename)}"
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

  name   = "${each.key}/${basename(each.value.filename)}"
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

  name   = "${each.key}/${basename(each.value.filename)}"
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

  name   = "${each.key}/ztp.iso"
  source = "${path.root}/${each.key}/${each.value.edge_vm}-${local.pov_edge_site}.iso"
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
