# Create GCE instance
resource "google_compute_instance" "nginx_vm" {
  name         = "${var.hostname}-${random_id.random_id.dec}"
  machine_type = var.machine_type
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.management.id

    access_config {
      nat_ip = google_compute_address.management_ip.address
    }
  }

  metadata = {
    ssh-keys = "${var.username}:${file("~/.ssh/id_rsa.pub")}"
  }

  metadata_startup_script = templatefile("${path.module}/nginx.tpl", {
    jwt_token    = file("${path.module}/secrets/nginx-repo.jwt")
    ssl_cert     = file("${path.module}/secrets/nginx-repo.crt")
    ssl_key      = file("${path.module}/secrets/nginx-repo.key")
    api_conf     = file("${path.module}/config/api.conf")
    demoapp_conf = file("${path.module}/config/demoapp.conf")
    dp_token     = var.dp_token
    username     = var.username
  })

  tags = ["nginx-vm"]

  labels = {
    owner = lower(replace(var.resourceOwner, " ", "-"))
  }
}
