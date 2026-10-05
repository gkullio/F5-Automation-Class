# ---------------------------------------------------------------------------
# Three VPC networks - one per BIG-IP interface.
#
# GCP requires each network interface on an instance to be in a DIFFERENT VPC
# network. This is the fundamental structural difference from AWS multi-NIC,
# where all ENIs share one VPC with different subnets.
# ---------------------------------------------------------------------------

resource "google_compute_network" "mgmt" {
  name                    = var.mgmt_vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "mgmt" {
  name          = var.mgmt_subnet_name
  ip_cidr_range = var.mgmt_cidr
  region        = var.region
  network       = google_compute_network.mgmt.id
}

resource "google_compute_network" "external" {
  name                    = var.external_vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "external" {
  name          = var.external_subnet_name
  ip_cidr_range = var.external_cidr
  region        = var.region
  network       = google_compute_network.external.id
}

resource "google_compute_network" "internal" {
  name                    = var.internal_vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "internal" {
  name          = var.internal_subnet_name
  ip_cidr_range = var.internal_cidr
  region        = var.region
  network       = google_compute_network.internal.id
}
