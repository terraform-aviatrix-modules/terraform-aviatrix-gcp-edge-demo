output "host_vm_details" {
  description = "Host and edge VM details."
  value       = local.host_vms
}

output "host_vm_pip" {
  description = "Host and edge VM details."
  value       = google_compute_address.host_vm_pip
}

output "test_vm_pip" {
  description = "Host and edge VM details."
  value       = google_compute_address.test_vm_pip
}