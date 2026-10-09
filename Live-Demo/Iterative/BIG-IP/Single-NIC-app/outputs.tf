output "BIG-IP-SSH" {
    value = "ssh admin@${module.bigip.management_public_ip}"
}

output "management_private_ip" {
  value = module.bigip.management_private_ip
}

output "resource_group_portal_url" {
  value = "https://portal.azure.com/#@/resource/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/overview"
}

output "BIG-IP-WebUI" {
  value = "https://${module.bigip.management_public_ip}:8443"
}

output "app_service_hostname_and_IP" {
  value = {
  description        = "Private IP address of the App Service (accessible only from within the VNet)"
  private-ip         = module.app-service.private_endpoint_ip
  hostname           = module.app-service.default_hostname
  }
}