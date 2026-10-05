# ---- Primary BIG-IP ---------------------------------------------------------
output "BIG-IP-1-SSH" {
  value = "ssh admin@${module.bigip.mgmt_public_ip_1}"
}

output "BIG-IP-1-UI" {
  value = "https://${module.bigip.mgmt_public_ip_1}"
}

output "BIG-IP-1-External" {
  value = "https://${module.bigip.external_public_ip_1}"
}

output "gcp_console_url_1" {
  value = "https://console.cloud.google.com/compute/instancesDetail/zones/${var.gcp_zone}/instances/${module.bigip.instance_name_1}?project=${var.gcp_project_id}"
}

output "onboarding_log_1" {
  value = "ssh admin@${module.bigip.mgmt_public_ip_1} 'tail -f /var/log/cloud/startup-script.log'"
}

# ---- Secondary BIG-IP -------------------------------------------------------
output "BIG-IP-2-SSH" {
  value = "ssh admin@${module.bigip.mgmt_public_ip_2}"
}

output "BIG-IP-2-UI" {
  value = "https://${module.bigip.mgmt_public_ip_2}"
}

output "BIG-IP-2-External" {
  value = "https://${module.bigip.external_public_ip_2}"
}

output "gcp_console_url_2" {
  value = "https://console.cloud.google.com/compute/instancesDetail/zones/${var.gcp_zone}/instances/${module.bigip.instance_name_2}?project=${var.gcp_project_id}"
}

output "onboarding_log_2" {
  value = "ssh admin@${module.bigip.mgmt_public_ip_2} 'tail -f /var/log/cloud/startup-script.log'"
}

# ---- HA VIP -----------------------------------------------------------------
output "HA-VIP" {
  value = "https://${module.bigip.vip_public_ip}"
}

output "external_floating_ip" {
  value = module.bigip.external_floating_ip
}

output "internal_floating_ip" {
  value = module.bigip.internal_floating_ip
}

# ---- Shared -----------------------------------------------------------------
output "bigip_image" {
  value = module.bigip.image_name
}

output "cfe_state_bucket" {
  value = module.bigip.cfe_state_bucket
}

output "serial_console_cmd_1" {
  value = "gcloud compute instances get-serial-port-output ${module.bigip.instance_name_1} --zone ${var.gcp_zone} --project ${var.gcp_project_id}"
}

output "serial_console_cmd_2" {
  value = "gcloud compute instances get-serial-port-output ${module.bigip.instance_name_2} --zone ${var.gcp_zone} --project ${var.gcp_project_id}"
}
