# Create F5 BIG-IP instance - single-NIC
resource "google_compute_instance" "bigip" {
  name         = var.vm_name == "" ? format("%s-f5vm01", var.instance_prefix) : var.vm_name
  machine_type = var.machine_type
  zone         = var.gcp_zone

  # Equivalent of AWS source_dest_check = false. Applies to all interfaces.
  # Required because the single interface carries data-plane traffic (SNATs
  # and forwards packets with addresses that are not its own).
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = data.google_compute_image.f5.self_link
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
  }

  network_interface {
    subnetwork = var.mgmt_subnet_self_link
    access_config {
      nat_ip = google_compute_address.mgmt.address
    }
  }

  metadata = {
    ssh-keys = "${var.f5_username}:${trimspace(file(var.ssh_publickey))}\n${var.f5_username_2}:${trimspace(file(var.ssh_publickey))}"
  }

  service_account {
    email  = google_service_account.bigip.email
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only"]
  }

  metadata_startup_script = coalesce(var.custom_user_data, templatefile("${path.module}/${var.script_name}.tmpl",
    {
      INIT_URL         = var.INIT_URL
      DO_VER           = format("v%s", split("-", var.do_rpm_file)[3])
      AS3_VER          = format("v%s", split("-", var.as3_rpm_file)[2])
      rpm_bucket       = google_storage_bucket.rpms.name
      do_rpm_key       = google_storage_bucket_object.do_rpm.name
      as3_rpm_key      = google_storage_bucket_object.as3_rpm.name
      license          = var.byol_license
      bigip_username   = var.f5_username
      bigip_username_2 = var.f5_username_2
      bigip_hostname   = var.bigip-hostname
      gcp_region       = var.gcp_region

      ssh_keypair    = trimspace(file(var.ssh_publickey))
      bigip_password = var.f5_password
      dns_server     = var.dns_server
      dns_suffix     = var.dns_suffix
      ntp_server     = var.ntp_server
      timezone       = var.timezone
  }))

  tags = ["${var.instance_prefix}-bigip"]

  labels = {
    owner   = local.owner_label
    project = lower(var.project_label)
  }

  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [
      boot_disk[0].initialize_params[0].image,
    ]
  }
}
