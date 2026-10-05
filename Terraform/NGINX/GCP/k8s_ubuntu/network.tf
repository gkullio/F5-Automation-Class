# GCP requires each NIC on a multi-NIC VM to be in a separate VPC network

# Management VPC
resource "google_compute_network" "mgmt_vpc" {
  name                    = "k8s-mgmt-vpc-${random_id.random_id.hex}"
  auto_create_subnetworks = false

  depends_on = [terraform_data.jwt_validation]
}

resource "google_compute_subnetwork" "management" {
  name          = "mgmt-subnet-${random_id.random_id.hex}"
  ip_cidr_range = var.mgmt_subnet_cidr
  region        = var.gcp_region
  network       = google_compute_network.mgmt_vpc.id
}

# Internal VPC
resource "google_compute_network" "int_vpc" {
  name                    = "k8s-int-vpc-${random_id.random_id.hex}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "internal" {
  name          = "int-subnet-${random_id.random_id.hex}"
  ip_cidr_range = var.int_subnet_cidr
  region        = var.gcp_region
  network       = google_compute_network.int_vpc.id
}

# Management firewall - SSH and application ports
resource "google_compute_firewall" "mgmt_admin_access" {
  name    = "k8s-mgmt-admin-${random_id.random_id.hex}"
  network = google_compute_network.mgmt_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8080", "8443"]
  }

  source_ranges = var.adminSrcAddr
  target_tags   = ["k8s-vm"]
}

# Internal firewall - application ports
resource "google_compute_firewall" "int_app_access" {
  name    = "k8s-int-app-${random_id.random_id.hex}"
  network = google_compute_network.int_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", "8443"]
  }

  source_ranges = var.adminSrcAddr
  target_tags   = ["k8s-vm"]
}

# Static external IP for management
resource "google_compute_address" "management_ip" {
  name   = "k8s-mgmt-ip-${random_id.random_id.hex}"
  region = var.gcp_region
}

# Static external IP for internal interface
resource "google_compute_address" "internal_ip" {
  name   = "k8s-int-ip-${random_id.random_id.hex}"
  region = var.gcp_region
}
