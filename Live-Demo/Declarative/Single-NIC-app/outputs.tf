output "BIG-IP-SSH" {
    value = "ssh admin@${module.bigip.management_public_ip}"
}

output "resource_group_portal_url" {
  value = "https://portal.azure.com/#@/resource/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/overview"
}

output "BIG-IP-WebUI" {
  value = "https://${module.bigip.management_public_ip}:8443"
}

output "app_service_private_endpoint_ip" {
  description = "Private IP address of the App Service (accessible only from within the VNet)"
  value       = module.app-service.private_endpoint_ip
}