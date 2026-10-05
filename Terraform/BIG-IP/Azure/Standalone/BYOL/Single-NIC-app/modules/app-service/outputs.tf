output "app_id" {
  description = "The ID of the Linux Web App"
  value       = azurerm_linux_web_app.this.id
}
output "default_hostname" {
  description = "The default hostname of the Linux Web App (e.g. <app_name>.azurewebsites.net)"
  value       = azurerm_linux_web_app.this.default_hostname
}
output "app_url" {
  description = "The full HTTPS URL of the Linux Web App"
  value       = "https://${azurerm_linux_web_app.this.default_hostname}"
}
output "service_plan_id" {
  description = "The ID of the App Service Plan"
  value       = local.service_plan_id
}
output "private_endpoint_ip" {
  description = "Private IP address of the App Service private endpoint"
  value       = var.subnet_id != null ? azurerm_private_endpoint.this[0].private_service_connection[0].private_ip_address : null
}