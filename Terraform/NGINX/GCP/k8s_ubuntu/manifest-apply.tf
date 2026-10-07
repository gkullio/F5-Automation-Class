resource "null_resource" "apply_manifests" {
  depends_on = [google_compute_instance.k8s_vm]

  connection {
    type        = "ssh"
    host        = google_compute_address.management_ip.address
    user        = var.username
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/${var.username}/manifests",
      "mkdir -p /home/${var.username}/secrets",
      "mkdir -p /home/${var.username}/scripts"
    ]
  }

  provisioner "file" {
    source      = "${path.module}/secrets"
    destination = "/home/${var.username}/"
  }

  provisioner "file" {
    source      = "${path.module}/manifests"
    destination = "/home/${var.username}/"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/post-provision.sh"
    destination = "/home/${var.username}/scripts/post-provision.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${var.username}/scripts/post-provision.sh",
      "/home/${var.username}/scripts/post-provision.sh"
    ]
  }
}
