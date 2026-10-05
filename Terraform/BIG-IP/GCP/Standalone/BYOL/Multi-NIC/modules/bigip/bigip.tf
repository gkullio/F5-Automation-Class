# Create F5 BIG-IP instance - multi-NIC (management + external + internal)
#
# GCP requires each network_interface to be in a different VPC network.
# The instance needs at least 8 vCPUs to support 3 NICs.
resource "google_compute_instance" "bigip" {
  name         = var.vm_name == "" ? format("%s-f5vm01", var.instance_prefix) : var.vm_name
  machine_type = var.machine_type
  zone         = var.gcp_zone

  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = data.google_compute_image.f5.self_link
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
  }

  # nic0 - management
  network_interface {
    subnetwork = var.mgmt_subnet_self_link
    access_config {
      nat_ip = google_compute_address.mgmt.address
    }
  }

  # nic1 - external (maps to BIG-IP 1.1)
  network_interface {
    subnetwork = var.external_subnet_self_link
    network_ip = google_compute_address.external_internal.address
    access_config {
      nat_ip = google_compute_address.external.address
    }
  }

  # nic2 - internal (maps to BIG-IP 1.2)
  network_interface {
    subnetwork = var.internal_subnet_self_link
    network_ip = google_compute_address.internal_internal.address
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

      # Multi-NIC: pre-allocated internal IPs for DO self-IPs
      external_self_ip = google_compute_address.external_internal.address
      internal_self_ip = google_compute_address.internal_internal.address
      external_gw      = var.external_gw
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
