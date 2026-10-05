output "NGINX_JWT_Info" {
  value = {
    f5_sat_expiry_date = local.f5_sat_rfc3339
    f5_sat_epoch       = local.f5_sat_epoch
  }
}

output "GCP_Info" {
  value = {
    Project = var.gcp_project
    Zone    = var.gcp_zone
    Console = "https://console.cloud.google.com/compute/instances?project=${var.gcp_project}"
  }
}

output "Management_Interface_Outputs" {
  value = {
    Management_Public_IP  = "ssh -i ~/.ssh/id_rsa ${var.username}@${google_compute_address.management_ip.address}"
    Management_Private_IP = google_compute_instance.nginx_vm.network_interface[0].network_ip
  }
}

output "Http_site_access" {
  value = "http://${google_compute_address.management_ip.address}"
}

output "Virtual_Machine_Info" {
  value = {
    Instance_Name = google_compute_instance.nginx_vm.name
    Machine_Type  = google_compute_instance.nginx_vm.machine_type
  }
}
