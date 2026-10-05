##################### Collect Public IP address #####################

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

resource "random_id" "random_id" {
  byte_length = 1
}

resource "azurerm_resource_group" "rg" {
    name                 = "${var.rg_name}-${random_id.random_id.dec}"
    location             = var.location
}

locals {
  my_public_ip = "${chomp(data.http.my_ip.response_body)}/32"
  tags = {
    owner = var.resourceOwner
    email = var.ownerEmail
  }
}

module "app-service" {
  source                    = "./modules/app-service"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = var.location
  app_name                  = "${var.app_name}-${random_id.random_id.dec}"
  create_service_plan       = var.create_service_plan
  service_plan_name         = var.service_plan_name
  sku_name                  = var.sku_name
  docker_image              = var.docker_image
  docker_registry_url       = var.docker_registry_url
  app_port                  = var.app_port
  always_on                 = var.always_on
  https_only                = var.https_only
  extra_app_settings        = var.extra_app_settings
  tags                      = local.tags
  existing_service_plan_id  = var.existing_service_plan_id
  enable_private_endpoint   = true
  subnet_id                 = module.azure-vnet.mgmt_subnet_id
  vnet_id                   = module.azure-vnet.vnet_id
}

module "azure-vnet" {
    source                  = "./modules/azure-vnet"
    resource_group_name     = azurerm_resource_group.rg.name
    location                = var.location
    vnet_name               = var.vnet_name
    vnet_address_space      = var.vnet_address_space
    mgmt_subnet_name        = var.mgmt_subnet_name
    mgmt_address_space      = var.mgmt_address_space
}


module "bigip" {
    source                  = "./modules/bigip"
    resource_group_name     = azurerm_resource_group.rg.name
    location                = var.location
    resourceOwner           = var.resourceOwner
    adminSrcAddr            = concat(var.vpnMgmtSrcAddr, [local.my_public_ip])
    REtrafficSrcAddr        = var.REtrafficSrcAddr
    vm_name                 = var.vm_name
    mgmt_subnet_id          = module.azure-vnet.mgmt_subnet_id
    instance_prefix         = var.instance_prefix

    # BIG-IP VE variables
    bigip-hostname          = var.bigip-hostname
    bigip-username          = var.bigip-username
    bigip-password          = var.bigip-password
    ssh_publickey           = var.ssh_publickey
    instance_size           = var.instance_size
    f5_product_name         = var.f5_product_name
    f5_image_name           = var.f5_image_name
    f5_version              = var.f5_version
    f5_username             = var.f5_username
    f5_username_2           = var.f5_username_2
    f5_password             = var.f5_password
    dns_suffix              = var.dns_suffix
    dns_server              = var.dns_server
    availability_zone       = var.availability_zone
    ntp_server              = var.ntp_server
    timezone                = var.timezone
    script_name             = var.script_name
    disable_ssh_key         = var.disable_ssh_key 
    INIT_URL                = var.INIT_URL
    asp_endpoint            = module.app-service.default_hostname
    asp_endpoint_ip         = module.app-service.private_endpoint_ip
}