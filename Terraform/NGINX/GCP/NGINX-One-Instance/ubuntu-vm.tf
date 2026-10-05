# Create GCE instance
/*
locals {
  jwt_token = file("${path.module}/secrets/nginx-repo.jwt")
  ssl_cert  = file("${path.module}/secrets/nginx-repo.crt")
  ssl_key   = file("${path.module}/secrets/nginx-repo.key")
  api_conf  = file("${path.module}/config/api.conf")
  spa_conf  = file("${path.module}/config/spa-app.conf")
  dp_token  = var.dp_token
  le_email  = var.le_email
  username  = var.username
}

data "template_file" "custom_script" {
  template = file("${path.module}/nginx.tpl")
  vars = {
    jwt_token = local.jwt_token
    ssl_cert  = local.ssl_cert
    ssl_key   = local.ssl_key
    api_conf  = local.api_conf
    spa_conf  = local.spa_conf
    dp_token  = local.dp_token
    le_email  = local.le_email
    username  = local.username
  }
}
*/

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

#  metadata_startup_script = data.template_file.custom_script.rendered

  # Direct call to templatefile() replaces data.template_file:
  metadata_startup_script = templatefile("${path.module}/nginx.tpl", {
    jwt_token = file("${path.module}/secrets/nginx-repo.jwt")
    ssl_cert  = file("${path.module}/secrets/nginx-repo.crt")
    ssl_key   = file("${path.module}/secrets/nginx-repo.key")
    api_conf  = file("${path.module}/config/api.conf")
    spa_conf  = file("${path.module}/config/spa-app.conf")
    dp_token  = var.dp_token
    le_email  = var.le_email
    username  = var.username
  })

  tags = ["nginx-vm"]

  labels = {
    owner = lower(replace(var.resourceOwner, " ", "-"))
  }
}
