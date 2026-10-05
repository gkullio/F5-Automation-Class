output "NGINX_JWT_Info" {
  value = {
    f5_sat_expiry_date = local.f5_sat_rfc3339
    f5_sat_epoch       = local.f5_sat_epoch
  }
}

output "Management_Public_IP" {
  value = "ssh -i ~/.ssh/id_rsa ${var.username}@${google_compute_address.management_ip.address}"
}

output "GCP_Info" {
  value = {
    Project = var.gcp_project
    Zone    = var.gcp_zone
    Console = "https://console.cloud.google.com/compute/instances?project=${var.gcp_project}"
  }
}
