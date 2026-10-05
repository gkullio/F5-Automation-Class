output "BIG-IP-SSH" {
  value = "ssh admin@${module.bigip.management_public_ip}"
}

output "BIG-IP-UI-ip" {
  value = "https://${module.bigip.management_public_ip}"
}

output "BIG-IP-External-VIP" {
  value = "https://${module.bigip.external_public_ip}"
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

output "management_private_ip" {
  value = module.bigip.management_private_ip
}

output "external_public_ip" {
  value = module.bigip.external_public_ip
}

output "external_private_ip" {
  value = module.bigip.external_private_ip
}

output "internal_private_ip" {
  value = module.bigip.internal_private_ip
}
