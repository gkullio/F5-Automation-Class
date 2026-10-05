# ---------------------------------------------------------------------------
# GCS bucket for F5 extension RPMs + CFE state bucket + service account
#
# The DO, AS3, and CFE RPMs in rpm_files/ are uploaded at apply time.
# A separate bucket stores CFE failover state. The service account gets
# broad compute + storage permissions so CFE can manage alias IPs,
# forwarding rules, and routes during failover.
# ---------------------------------------------------------------------------

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  rpm_bucket_name = replace(
    lower("${var.instance_prefix}-bigip-rpms-${random_id.bucket_suffix.hex}"),
    "_", "-"
  )
  cfe_bucket_name = replace(
    lower("${var.instance_prefix}-bigip-cfe-${random_id.bucket_suffix.hex}"),
    "_", "-"
  )
  do_rpm_path  = "${path.module}/rpm_files/${var.do_rpm_file}"
  as3_rpm_path = "${path.module}/rpm_files/${var.as3_rpm_file}"
  cfe_rpm_path = "${path.module}/rpm_files/${var.cfe_rpm_file}"
}

# ---- RPM GCS bucket ---------------------------------------------------------

resource "google_storage_bucket" "rpms" {
  name          = local.rpm_bucket_name
  location      = var.gcp_region
  force_destroy = true

  uniform_bucket_level_access = true

  labels = {
    purpose = "bigip-rpms"
  }
}

# ---- RPM objects -------------------------------------------------------------

resource "google_storage_bucket_object" "do_rpm" {
  name   = var.do_rpm_file
  bucket = google_storage_bucket.rpms.name
  source = local.do_rpm_path
}

resource "google_storage_bucket_object" "as3_rpm" {
  name   = var.as3_rpm_file
  bucket = google_storage_bucket.rpms.name
  source = local.as3_rpm_path
}

resource "google_storage_bucket_object" "cfe_rpm" {
  name   = var.cfe_rpm_file
  bucket = google_storage_bucket.rpms.name
  source = local.cfe_rpm_path
}

# ---- CFE state GCS bucket ---------------------------------------------------

resource "google_storage_bucket" "cfe_state" {
  name          = local.cfe_bucket_name
  location      = var.gcp_region
  force_destroy = true

  uniform_bucket_level_access = true

  labels = {
    f5_cloud_failover_label = var.cfe_label
  }
}

# ---- Service account + IAM ---------------------------------------------------

resource "google_service_account" "bigip" {
  account_id   = "${var.instance_prefix}-bigip-sa"
  display_name = "BIG-IP HA pair service account (CFE + GCS RPM access)"
}

resource "google_project_iam_member" "bigip_compute" {
  project = var.gcp_project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.bigip.email}"
}

resource "google_project_iam_member" "bigip_storage" {
  project = var.gcp_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.bigip.email}"
}

resource "google_project_iam_member" "bigip_network" {
  project = var.gcp_project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${google_service_account.bigip.email}"
}
