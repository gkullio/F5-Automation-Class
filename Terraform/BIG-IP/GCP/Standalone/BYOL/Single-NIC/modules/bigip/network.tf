# ---------------------------------------------------------------------------
# BIG-IP image lookup
#
# F5 publishes images in the f5-7626-networks-public project. Find available
# images with:
#   gcloud compute images list --project f5-7626-networks-public \
#     --filter="name~bigip" --sort-by=~creationTimestamp --limit=10
# ---------------------------------------------------------------------------

data "google_compute_image" "f5" {
  project = var.f5_image_project
  name    = var.f5_image_name
}

# ---------------------------------------------------------------------------
# Firewall rules - the security-group equivalent.
#
# GCP firewall rules live at the VPC level and target instances by network
# tag, not by attachment to a specific NIC. On single-NIC the management and
# data planes share one interface, so both admin and app rules target the
# same tag.
# ---------------------------------------------------------------------------

locals {
  admin_ports = ["22", "8443"]
  app_ports   = ["80", "443", "8080", "8081"]
}

resource "google_compute_firewall" "mgmt" {
  name    = "${var.instance_prefix}-bigip-mgmt-fw"
  network = var.vpc_self_link

  allow {
    protocol = "tcp"
    ports    = local.admin_ports
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = var.adminSrcAddr
  target_tags   = ["${var.instance_prefix}-bigip"]
}

resource "google_compute_firewall" "app" {
  name    = "${var.instance_prefix}-bigip-app-fw"
  network = var.vpc_self_link

  allow {
    protocol = "tcp"
    ports    = local.app_ports
  }

  source_ranges = var.REtrafficSrcAddr
  target_tags   = ["${var.instance_prefix}-bigip"]
}

# ---------------------------------------------------------------------------
# Static external IP - the Elastic IP equivalent.
# ---------------------------------------------------------------------------

resource "google_compute_address" "mgmt" {
  name   = "${var.instance_prefix}-bigip-mgmt-eip"
  region = var.gcp_region
}

