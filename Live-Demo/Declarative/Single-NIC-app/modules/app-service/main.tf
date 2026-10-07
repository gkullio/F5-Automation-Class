# Service Plan (Linux)
resource "azurerm_service_plan" "this" {
  count                            = var.create_service_plan ? 1 : 0
  name                             = var.service_plan_name != null ? var.service_plan_name : "${var.app_name}-asp"
  resource_group_name              = var.resource_group_name
  location                         = var.location
  os_type                          = "Linux"
  sku_name                         = var.sku_name
  tags                             = var.tags
}

# Private Endpoint for the App Service
resource "azurerm_private_endpoint" "this" {
  count                            = var.enable_private_endpoint ? 1 : 0
  name                             = "${var.app_name}-pe"
  resource_group_name              = var.resource_group_name
  location                         = var.location
  subnet_id                        = var.subnet_id
  tags                             = var.tags

  private_service_connection {
    name                           = "${var.app_name}-psc"
    private_connection_resource_id = azurerm_linux_web_app.this.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                          = "default"
    private_dns_zone_ids          = [azurerm_private_dns_zone.this[0].id]
  }
}

# Private DNS Zone so the App Service FQDN resolves to its private IP within the VNet
resource "azurerm_private_dns_zone" "this" {
  count                           = var.enable_private_endpoint ? 1 : 0
  name                            = "privatelink.azurewebsites.net"
  resource_group_name             = var.resource_group_name
  tags                            = var.tags
}

# Link the private DNS zone to the VNet
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  count                           = var.enable_private_endpoint ? 1 : 0
  name                            = "${var.app_name}-vnet-link"
  resource_group_name             = var.resource_group_name
  private_dns_zone_name           = azurerm_private_dns_zone.this[0].name
  virtual_network_id              = var.vnet_id
  registration_enabled            = false
  tags                            = var.tags
}
locals {
  service_plan_id = var.create_service_plan ? azurerm_service_plan.this[0].id : var.existing_service_plan_id
}
# Linux Web App running Docker Container
resource "azurerm_linux_web_app" "this" {
  name                            = var.app_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  service_plan_id                 = local.service_plan_id
  https_only                      = var.https_only
  public_network_access_enabled   = false
  site_config {
    always_on = var.always_on
    application_stack {
      docker_image_name           = var.docker_image
      docker_registry_url         = var.docker_registry_url
    }
  }
  app_settings = merge(
    {
      # Tells Azure App Service to route incoming HTTP traffic (port 80/443) to port 8080 inside the container
      "WEBSITES_PORT" = tostring(var.app_port)
      "PORT"          = tostring(var.app_port)
    },
    var.extra_app_settings
  )
  tags = var.tags
}