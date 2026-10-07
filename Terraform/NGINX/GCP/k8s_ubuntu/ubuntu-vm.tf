# Create GCE instance
resource "google_compute_instance" "k8s_vm" {
  name         = var.hostname
  machine_type = var.machine_type
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 30
      type  = "pd-ssd"
    }
  }

  # Management NIC (nic0) - external access
  network_interface {
    subnetwork = google_compute_subnetwork.management.id

    access_config {
      nat_ip = google_compute_address.management_ip.address
    }
  }

  # Internal NIC (nic1) - application traffic
  network_interface {
    subnetwork = google_compute_subnetwork.internal.id
    network_ip = "10.245.2.99"

    access_config {
      nat_ip = google_compute_address.internal_ip.address
    }

    alias_ip_range {
      ip_cidr_range = "10.245.2.100/32"
    }
    alias_ip_range {
      ip_cidr_range = "10.245.2.101/32"
    }
    alias_ip_range {
      ip_cidr_range = "10.245.2.102/32"
    }
    alias_ip_range {
      ip_cidr_range = "10.245.2.103/32"
    }
    alias_ip_range {
      ip_cidr_range = "10.245.2.104/32"
    }
    alias_ip_range {
      ip_cidr_range = "10.245.2.105/32"
    }
  }

  metadata = {
    ssh-keys = "${var.username}:${file("~/.ssh/id_rsa.pub")}"
  }

  metadata_startup_script = templatefile("${path.module}/scripts/k8s.tpl", {
    username = var.username
  })

  tags = ["k8s-vm"]

  labels = {
    owner = lower(replace(var.resourceOwner, " ", "-"))
  }
}
