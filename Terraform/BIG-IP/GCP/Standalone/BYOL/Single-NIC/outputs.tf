output "BIG-IP-SSH" {
  value = "ssh admin@${module.bigip.management_public_ip}"
}

output "BIG-IP-UI-ip" {
  value = "https://${module.bigip.management_public_ip}:8443"
}

output "gcp_console_url" {
  value = "https://console.cloud.google.com/compute/instancesDetail/zones/${var.gcp_zone}/instances/${module.bigip.instance_name}?project=${var.gcp_project_id}"
}

output "bigip_image" {
  value = module.bigip.image_name
}

output "onboarding_log_tail" {
  value = "ssh admin@${module.bigip.management_public_ip} 'tail -f /var/log/cloud/startup-script.log'"
}

output "serial_console_cmd" {
  value = "gcloud compute instances get-serial-port-output ${module.bigip.instance_name} --zone ${var.gcp_zone} --project ${var.gcp_project_id}"
}
