# ---------------------------------------------------------------------------
# BIG-IP image lookup
# ---------------------------------------------------------------------------

data "google_compute_image" "f5" {
  project = var.f5_image_project
  name    = var.f5_image_name
}

# ---------------------------------------------------------------------------
# Firewall rules - one set per VPC network, shared by both HA instances.
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

resource "google_compute_firewall" "mgmt_ha" {
  name    = "${var.instance_prefix}-bigip-mgmt-ha-fw"
  network = var.mgmt_vpc_self_link

  allow {
    protocol = "tcp"
    ports    = ["443", "4353"]
  }

  allow {
    protocol = "udp"
    ports    = ["1026"]
  }

  source_tags = ["${var.instance_prefix}-bigip"]
  target_tags = ["${var.instance_prefix}-bigip"]
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
# Static external IPs - per-instance management and external IPs.
# ---------------------------------------------------------------------------

resource "google_compute_address" "mgmt_1" {
  name   = "${var.instance_prefix}-bigip1-mgmt-eip"
  region = var.gcp_region
}

resource "google_compute_address" "mgmt_2" {
  name   = "${var.instance_prefix}-bigip2-mgmt-eip"
  region = var.gcp_region
}

resource "google_compute_address" "external_1" {
  name   = "${var.instance_prefix}-bigip1-external-eip"
  region = var.gcp_region
}

resource "google_compute_address" "external_2" {
  name   = "${var.instance_prefix}-bigip2-external-eip"
  region = var.gcp_region
}

# Static external IP for the HA VIP (forwarding rule)
resource "google_compute_address" "vip" {
  name   = "${var.instance_prefix}-bigip-ha-vip"
  region = var.gcp_region
}

# ---------------------------------------------------------------------------
# Internal IP reservations - per-instance data-plane interfaces.
# ---------------------------------------------------------------------------

resource "google_compute_address" "mgmt_internal_1" {
  name         = "${var.instance_prefix}-bigip1-mgmt-int-ip"
  subnetwork   = var.mgmt_subnet_self_link
  address_type = "INTERNAL"
  region       = var.gcp_region
}

resource "google_compute_address" "mgmt_internal_2" {
  name         = "${var.instance_prefix}-bigip2-mgmt-int-ip"
  subnetwork   = var.mgmt_subnet_self_link
  address_type = "INTERNAL"
  region       = var.gcp_region
}

resource "google_compute_address" "external_internal_1" {
  name         = "${var.instance_prefix}-bigip1-external-int-ip"
  subnetwork   = var.external_subnet_self_link
  address_type = "INTERNAL"
  region       = var.gcp_region
}

resource "google_compute_address" "external_internal_2" {
  name         = "${var.instance_prefix}-bigip2-external-int-ip"
  subnetwork   = var.external_subnet_self_link
  address_type = "INTERNAL"
  region       = var.gcp_region
}

resource "google_compute_address" "internal_internal_1" {
  name         = "${var.instance_prefix}-bigip1-internal-int-ip"
  subnetwork   = var.internal_subnet_self_link
  address_type = "INTERNAL"
  region       = var.gcp_region
}

resource "google_compute_address" "internal_internal_2" {
  name         = "${var.instance_prefix}-bigip2-internal-int-ip"
  subnetwork   = var.internal_subnet_self_link
  address_type = "INTERNAL"
  region       = var.gcp_region
}

# ---------------------------------------------------------------------------
# Floating IPs - used as BIG-IP floating self-IPs and GCP alias IPs.
# CFE moves the alias IP assignments between instances on failover.
# ---------------------------------------------------------------------------

resource "google_compute_address" "external_floating" {
  name         = "${var.instance_prefix}-bigip-external-floating-ip"
  subnetwork   = var.external_subnet_self_link
  address_type = "INTERNAL"
  region       = var.gcp_region
}

resource "google_compute_address" "internal_floating" {
  name         = "${var.instance_prefix}-bigip-internal-floating-ip"
  subnetwork   = var.internal_subnet_self_link
  address_type = "INTERNAL"
  region       = var.gcp_region
}

# ---------------------------------------------------------------------------
# Forwarding rule + target instances - public VIP for virtual server traffic.
# CFE updates the forwarding rule target on failover.
# ---------------------------------------------------------------------------

resource "google_compute_target_instance" "bigip1" {
  name     = "${var.instance_prefix}-bigip1-target"
  instance = google_compute_instance.bigip1.self_link
  zone     = var.gcp_zone
}

resource "google_compute_target_instance" "bigip2" {
  name     = "${var.instance_prefix}-bigip2-target"
  instance = google_compute_instance.bigip2.self_link
  zone     = var.gcp_zone
}

resource "google_compute_forwarding_rule" "vip" {
  name        = "${var.instance_prefix}-bigip-ha-vip"
  region      = var.gcp_region
  ip_address  = google_compute_address.vip.address
  ip_protocol = "TCP"
  port_range  = "1-65535"
  target      = google_compute_target_instance.bigip1.self_link

  labels = {
    f5_cloud_failover_label = var.cfe_label
  }

  lifecycle {
    ignore_changes = [target]
  }
}
