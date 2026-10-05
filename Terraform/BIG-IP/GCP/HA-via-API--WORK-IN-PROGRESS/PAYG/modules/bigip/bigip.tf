# ---------------------------------------------------------------------------
# BIG-IP HA pair - two instances with Cloud Failover Extension
#
# Primary (bigip1) boots first. Secondary (bigip2) waits for primary to
# complete onboarding before running its own runtime-init, which includes
# DeviceTrust and DeviceGroup declarations to form the HA pair.
# ---------------------------------------------------------------------------

# ---- Primary BIG-IP ---------------------------------------------------------

resource "google_compute_instance" "bigip1" {
  name         = var.vm_name_1
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
    network_ip = google_compute_address.mgmt_internal_1.address
    access_config {
      nat_ip = google_compute_address.mgmt_1.address
    }
  }

  # nic1 - external (BIG-IP 1.1) + floating alias IP
  network_interface {
    subnetwork = var.external_subnet_self_link
    network_ip = google_compute_address.external_internal_1.address
    alias_ip_range {
      ip_cidr_range = "${google_compute_address.external_floating.address}/32"
    }
    access_config {
      nat_ip = google_compute_address.external_1.address
    }
  }

  # nic2 - internal (BIG-IP 1.2) + floating alias IP
  network_interface {
    subnetwork = var.internal_subnet_self_link
    network_ip = google_compute_address.internal_internal_1.address
    alias_ip_range {
      ip_cidr_range = "${google_compute_address.internal_floating.address}/32"
    }
  }

  metadata = {
    ssh-keys = "${var.f5_username}:${trimspace(file(var.ssh_publickey))}\n${var.f5_username_2}:${trimspace(file(var.ssh_publickey))}"
  }

  service_account {
    email  = google_service_account.bigip.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/f5_onboard_primary.tmpl",
    {
      INIT_URL         = var.INIT_URL
      DO_VER           = format("v%s", split("-", var.do_rpm_file)[3])
      AS3_VER          = format("v%s", split("-", var.as3_rpm_file)[2])
      CFE_VER          = format("v%s", split("-", var.cfe_rpm_file)[3])
      rpm_bucket       = google_storage_bucket.rpms.name
      do_rpm_key       = google_storage_bucket_object.do_rpm.name
      as3_rpm_key      = google_storage_bucket_object.as3_rpm.name
      cfe_rpm_key      = google_storage_bucket_object.cfe_rpm.name
      bigip_username   = var.f5_username
      bigip_username_2 = var.f5_username_2
      bigip_hostname   = var.bigip_hostname_1
      gcp_region       = var.gcp_region

      ssh_keypair    = trimspace(file(var.ssh_publickey))
      bigip_password = var.f5_password
      dns_server     = var.dns_server
      dns_suffix     = var.dns_suffix
      ntp_server     = var.ntp_server
      timezone       = var.timezone

      external_self_ip     = google_compute_address.external_internal_1.address
      internal_self_ip     = google_compute_address.internal_internal_1.address
      external_floating_ip = google_compute_address.external_floating.address
      internal_floating_ip = google_compute_address.internal_floating.address
      external_gw          = var.external_gw
      cfe_label            = var.cfe_label
  })

  tags = ["${var.instance_prefix}-bigip"]

  labels = {
    owner                   = local.owner_label
    project                 = lower(var.project_label)
    f5_cloud_failover_label = var.cfe_label
  }

  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [
      boot_disk[0].initialize_params[0].image,
      network_interface[1].alias_ip_range,
      network_interface[2].alias_ip_range,
    ]
  }
}

# ---- Delay between instances ------------------------------------------------

resource "time_sleep" "wait_for_primary" {
  depends_on      = [google_compute_instance.bigip1]
  create_duration = "120s"
}

# ---- Secondary BIG-IP -------------------------------------------------------

resource "google_compute_instance" "bigip2" {
  depends_on = [time_sleep.wait_for_primary]

  name         = var.vm_name_2
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
    network_ip = google_compute_address.mgmt_internal_2.address
    access_config {
      nat_ip = google_compute_address.mgmt_2.address
    }
  }

  # nic1 - external (BIG-IP 1.1) - no alias IPs initially (CFE adds on failover)
  network_interface {
    subnetwork = var.external_subnet_self_link
    network_ip = google_compute_address.external_internal_2.address
    access_config {
      nat_ip = google_compute_address.external_2.address
    }
  }

  # nic2 - internal (BIG-IP 1.2)
  network_interface {
    subnetwork = var.internal_subnet_self_link
    network_ip = google_compute_address.internal_internal_2.address
  }

  metadata = {
    ssh-keys = "${var.f5_username}:${trimspace(file(var.ssh_publickey))}\n${var.f5_username_2}:${trimspace(file(var.ssh_publickey))}"
  }

  service_account {
    email  = google_service_account.bigip.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/f5_onboard_secondary.tmpl",
    {
      INIT_URL         = var.INIT_URL
      DO_VER           = format("v%s", split("-", var.do_rpm_file)[3])
      AS3_VER          = format("v%s", split("-", var.as3_rpm_file)[2])
      CFE_VER          = format("v%s", split("-", var.cfe_rpm_file)[3])
      rpm_bucket       = google_storage_bucket.rpms.name
      do_rpm_key       = google_storage_bucket_object.do_rpm.name
      as3_rpm_key      = google_storage_bucket_object.as3_rpm.name
      cfe_rpm_key      = google_storage_bucket_object.cfe_rpm.name
      bigip_username   = var.f5_username
      bigip_username_2 = var.f5_username_2
      bigip_hostname   = var.bigip_hostname_2
      gcp_region       = var.gcp_region

      ssh_keypair    = trimspace(file(var.ssh_publickey))
      bigip_password = var.f5_password
      dns_server     = var.dns_server
      dns_suffix     = var.dns_suffix
      ntp_server     = var.ntp_server
      timezone       = var.timezone

      external_self_ip     = google_compute_address.external_internal_2.address
      internal_self_ip     = google_compute_address.internal_internal_2.address
      external_floating_ip = google_compute_address.external_floating.address
      internal_floating_ip = google_compute_address.internal_floating.address
      external_gw          = var.external_gw
      cfe_label            = var.cfe_label

      primary_mgmt_private_ip = google_compute_address.mgmt_internal_1.address
      primary_hostname        = var.bigip_hostname_1
  })

  tags = ["${var.instance_prefix}-bigip"]

  labels = {
    owner                   = local.owner_label
    project                 = lower(var.project_label)
    f5_cloud_failover_label = var.cfe_label
  }

  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [
      boot_disk[0].initialize_params[0].image,
      network_interface[1].alias_ip_range,
      network_interface[2].alias_ip_range,
    ]
  }
}
