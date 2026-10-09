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

module "distributed_cloud" {
    source                                        = "./modules/distributed_cloud"

# Global Variables
    xc_api_creds                                  = var.xc_api_creds
    xc_api_url                                    = var.xc_api_url
    xc_namespace                                  = var.xc_namespace
    my_name                                       = var.my_name

    app_fw_name                                   = var.app_fw_name
# Response Code Options
    allow_all_response_codes                      = var.allow_all_response_codes
    allowed_response_codes                        = var.allowed_response_codes
# Anonymization Options
    anonymization_mode                            = var.anonymization_mode
    custom_anonymization_configs                  = var.custom_anonymization_configs
# Enforcement Mode Options
    enforcement_mode                              = var.enforcement_mode
# Blocking Page Options
    use_default_blocking_page                     = var.use_default_blocking_page
# AI Enhancements Options
    disable_ai_enhancements                       = var.disable_ai_enhancements
    enable_ai_enhancements                        = var.enable_ai_enhancements
    ai_mitigate_high_medium_risk_action           = var.ai_mitigate_high_medium_risk_action
    ai_mitigate_high_risk_action                  = var.ai_mitigate_high_risk_action
# Detection Settings Options
    use_default_detection_settings                = var.use_default_detection_settings
    detection_default_bot_setting                 = var.detection_default_bot_setting
    detection_enable_suppression                  = var.detection_enable_suppression
    detection_default_attack_type_settings        = var.detection_default_attack_type_settings
    detection_high_medium_low_accuracy_signatures = var.detection_high_medium_low_accuracy_signatures
    detection_disable_staging                     = var.detection_disable_staging
    detection_enable_threat_campaigns             = var.detection_enable_threat_campaigns
# Bot Detection Settings
    bot_setting_mode                              = var.bot_setting_mode
    good_bot_action                               = var.good_bot_action
    malicious_bot_action                          = var.malicious_bot_action
    suspicious_bot_action                         = var.suspicious_bot_action
# Attack Signature Staging
    staging_mode                                  = var.staging_mode
    staging_period_days                           = var.staging_period_days
# Threat Campaigns
    enable_threat_campaigns                       = var.enable_threat_campaigns
# Automatic Attack Signature Tuning (Suppression)
    enable_suppression                            = var.enable_suppression
# Attack Types
    use_default_attack_types                      = var.use_default_attack_types
    disabled_attack_types                         = var.disabled_attack_types
# Signature Selection by Accuracy
    accuracy_signature_selection                  = var.accuracy_signature_selection
# Violations View
    violations_list                               = var.violations_list
# HTTP Load Balancer Variables
    delegated_dns_domain                          = var.delegated_dns_domain
    enable_ip_reputation                          = var.enable_ip_reputation
    ip_threat_categories                          = var.ip_threat_categories
# Origin Pool Variables
    public_ip                                     = module.bigip.management_public_ip
}