resource "google_compute_network" "vpc" {
  name                    = "nginx-vpc-${random_id.random_id.hex}"
  auto_create_subnetworks = false

  depends_on = [terraform_data.jwt_validation]
}

resource "google_compute_subnetwork" "management" {
  name          = "mgmt-subnet-${random_id.random_id.hex}"
  ip_cidr_range = var.mgmt_subnet_cidr
  region        = var.gcp_region
  network       = google_compute_network.vpc.id
}

resource "google_compute_subnetwork" "internal" {
  name          = "int-subnet-${random_id.random_id.hex}"
  ip_cidr_range = var.int_subnet_cidr
  region        = var.gcp_region
  network       = google_compute_network.vpc.id
}

# Firewall rule - Admin access (SSH and application ports)
resource "google_compute_firewall" "admin_access" {
  name    = "admin-access-${random_id.random_id.hex}"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8080", "8443", "9000", "8000", "8001", "8002", "8081", "8082", "8003"]
  }

  source_ranges = var.adminSrcAddr
  target_tags   = ["nginx-vm"]
}

# Firewall rule - Let's Encrypt HTTP challenge (open to all)
resource "google_compute_firewall" "lets_encrypt" {
  name    = "lets-encrypt-${random_id.random_id.hex}"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["nginx-vm"]
}

# Static external IP for the management interface
resource "google_compute_address" "management_ip" {
  name   = "nginx-mgmt-ip-${random_id.random_id.hex}"
  region = var.gcp_region
}
