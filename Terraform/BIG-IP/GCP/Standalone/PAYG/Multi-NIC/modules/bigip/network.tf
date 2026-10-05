# ---------------------------------------------------------------------------
# BIG-IP image lookup
# ---------------------------------------------------------------------------

data "google_compute_image" "f5" {
  project = var.f5_image_project
  name    = var.f5_image_name
}

# ---------------------------------------------------------------------------
# Firewall rules - one set per VPC network.
#
# GCP firewall rules are scoped to a network. Even though all three rules
# target the same tag, each only applies to traffic on its own VPC's
# interface.
#
#   mgmt     - SSH + TMUI (443; dedicated mgmt interface owns 443)
#   external - virtual-server traffic
#   internal - all traffic from RFC1918 ranges
# ---------------------------------------------------------------------------

resource "google_compute_firewall" "mgmt" {
  name    = "${var.instance_prefix}-bigip-mgmt-fw"
  network = var.mgmt_vpc_self_link

  allow {
    protocol = "tcp"
    ports    = ["22", "443"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = var.adminSrcAddr
  target_tags   = ["${var.instance_prefix}-bigip"]
}

resource "google_compute_firewall" "external" {
  name    = "${var.instance_prefix}-bigip-external-fw"
  network = var.external_vpc_self_link

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", "8081"]
  }

  source_ranges = var.REtrafficSrcAddr
  target_tags   = ["${var.instance_prefix}-bigip"]
}

resource "google_compute_firewall" "internal" {
  name    = "${var.instance_prefix}-bigip-internal-fw"
  network = var.internal_vpc_self_link

  allow {
    protocol = "all"
  }

  source_ranges = ["10.0.0.0/8"]
  target_tags   = ["${var.instance_prefix}-bigip"]
}

# ---------------------------------------------------------------------------
# Static external IPs - management for admin, external for virtual servers.
# ---------------------------------------------------------------------------

resource "google_compute_address" "mgmt" {
  name   = "${var.instance_prefix}-bigip-mgmt-eip"
  region = var.gcp_region
}

resource "google_compute_address" "external" {
  name   = "${var.instance_prefix}-bigip-external-eip"
  region = var.gcp_region
}

# ---------------------------------------------------------------------------
# Internal IP reservations for the data-plane interfaces.
#
# Pre-allocating these avoids a circular dependency: the instance needs the
# IPs in its startup script (for DO self-IPs), but GCP would only assign
# them when the instance is created.
# ---------------------------------------------------------------------------

resource "google_compute_address" "external_internal" {
  name         = "${var.instance_prefix}-bigip-external-int-ip"
  subnetwork   = var.external_subnet_self_link
  address_type = "INTERNAL"
  region       = var.gcp_region
}

resource "google_compute_address" "internal_internal" {
  name         = "${var.instance_prefix}-bigip-internal-int-ip"
  subnetwork   = var.internal_subnet_self_link
  address_type = "INTERNAL"
  region       = var.gcp_region
}
