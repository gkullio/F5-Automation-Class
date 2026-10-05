resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "mgmt" {
  name          = var.mgmt_subnet_name
  ip_cidr_range = var.mgmt_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}
