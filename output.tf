output "host_vm_details" {
  description = "Host and edge VM details."
  value       = local.host_vms
}

output "host_pip_details" {
  description = "Host and edge VM details."
  value       = google_compute_address.host_vm_pip
}
