output "BIG-IP-SSH" {
    value = "ssh admin@${module.bigip.management_public_ip}"
}

output "resource_group_portal_url" {
  value = "https://portal.azure.com/#@/resource/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/overview"
}

output "BIG-IP-WebUI" {
  value = "https://${module.bigip.management_public_ip}:8443"
}

output "BIG-IP-External-IP" {
  value = module.bigip.external_public_ip
}
