# GCP Network

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

#HA Ports ILB
resource "google_compute_region_health_check" "health_check" {
  name = local.hc_name

  check_interval_sec = 15

  tcp_health_check {
    port = "179"
  }
}

resource "google_compute_region_backend_service" "backend_service" {
  name = local.backend_service_name
  health_checks = [ google_compute_region_health_check.health_check.id ]
  protocol = "TCP"
  load_balancing_scheme = "INTERNAL"

  dynamic "backend" {
    for_each = google_compute_instance_group.instance_group
    content {
      group =  backend.value.id
    }
  }
}

resource "google_compute_forwarding_rule" "forwarding_rule" {
  name                  = local.forwarding_rule_name
  backend_service       = google_compute_region_backend_service.backend_service.id
  ip_protocol           = "TCP"
  ip_address = local.ilb_vpc_ip
  load_balancing_scheme = "INTERNAL"
  all_ports             = true
  allow_global_access   = true
  network               = google_compute_network.vpc_network.id
  subnetwork            = google_compute_subnetwork.vpc_subnet.id
}