# ---------------------------------------------------------------------------
# GCS bucket for F5 extension RPMs + service account
#
# The DO and AS3 RPMs checked into rpm_files/ are uploaded here at apply
# time.  The BIG-IP downloads them at first boot via an OAuth2 token from
# the GCP metadata server (see gcs_download.py in f5_onboard.tmpl) before
# runtime-init runs, so the extensions install from local file:// paths
# with no external network dependency.
# ---------------------------------------------------------------------------

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  rpm_bucket_name = replace(
    lower("${var.instance_prefix}-bigip-rpms-${random_id.bucket_suffix.hex}"),
    "_", "-"
  )
  do_rpm_path  = "${path.module}/rpm_files/${var.do_rpm_file}"
  as3_rpm_path = "${path.module}/rpm_files/${var.as3_rpm_file}"
}

# ---- GCS bucket -------------------------------------------------------------

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

# ---- Service account + IAM ---------------------------------------------------

resource "google_service_account" "bigip" {
  account_id   = "${var.instance_prefix}-bigip-sa"
  display_name = "BIG-IP instance service account for GCS RPM access"
}

resource "google_storage_bucket_iam_member" "bigip_rpm_reader" {
  bucket = google_storage_bucket.rpms.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.bigip.email}"
}
