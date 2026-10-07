# Azure Credentials
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "subscription_id" {}

# Global Variables
variable "rg_name" {}
variable "resourceOwner" {}
variable "ownerEmail" {}
variable "location" {}
variable "instance_size" {}
variable "tenant" {}

####### Module app-service #######

variable "app_name" {}
variable "create_service_plan" {}
variable "existing_service_plan_id" {}
variable "service_plan_name" {}
variable "sku_name" {}
variable "docker_image" {}
variable "docker_registry_url" {}
variable "app_port" {}
variable "always_on" {}
variable "https_only" {}
variable "extra_app_settings" {}

####### Module azure_vnet #######

variable "vnet_name" {}
variable "vnet_address_space" {}
variable "mgmt_subnet_name" {}
variable "mgmt_address_space" {}

####### Module BIG-IP VM #######

variable "vm_name" {}
variable "instance_prefix" {}
variable "bigip-username" {}
variable "bigip-password" {}

## Networking source address lists  ##

variable "vpnMgmtSrcAddr" {}
variable "REtrafficSrcAddr" {}

## BIG-IP VE specific variables ##
variable "bigip-hostname" {}
variable "ssh_publickey" {}
variable "f5_product_name" {}
variable "f5_image_name" {}
variable "f5_version" {}
variable "f5_username" {}
variable "f5_username_2" {}
variable "dns_suffix" {}
variable "dns_server" {}
variable "availability_zone" {}
variable "ntp_server" {}
variable "timezone" {}
variable "f5_password" {}
variable "script_name" {}
variable "disable_ssh_key" {}
variable "INIT_URL" {
    type = string
    default = "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/2.0.3/f5-bigip-runtime-init-2.0.3-1.gz.run"
}

#################################################
####### Distributed Cloud Variables #######
#################################################

#################################################
####### Global Variables #######
#################################################

variable xc_api_creds {}
variable xc_api_url {}
variable xc_namespace {}
variable my_name {}

#################################################
####### Web Application Firewall Variables #######
#################################################

variable app_fw_name {}

## Response Code Options 
variable allow_all_response_codes {}
variable allowed_response_codes {}

## Anonymization Options 
variable anonymization_mode {}
variable custom_anonymization_configs {}

## Enforcement Mode Options 
variable enforcement_mode {}

## Blocking Page Options 
variable use_default_blocking_page {}

## AI Enhancements Options 
variable disable_ai_enhancements {}

## Detection Settings Options 
variable use_default_detection_settings {}
variable detection_default_bot_setting {}
variable detection_enable_suppression {}
variable detection_default_attack_type_settings {}
variable detection_high_medium_low_accuracy_signatures {}
variable detection_disable_staging {}
variable detection_enable_threat_campaigns {}

##  AI Enhancements Options 
variable enable_ai_enhancements {}
variable ai_mitigate_high_medium_risk_action {}
variable ai_mitigate_high_risk_action {}

####### Detection Settings #######

## 1. BOT DETECTION SETTINGS
variable bot_setting_mode {}
variable good_bot_action {}
variable malicious_bot_action {}
variable suspicious_bot_action {}


## 2. ATTACK SIGNATURE STAGING
variable staging_mode {}
variable staging_period_days {}


## 3. THREAT CAMPAIGNS
variable enable_threat_campaigns {}

## 4. AUTOMATIC ATTACK SIGNATURE TUNING (SUPPRESSION)
variable enable_suppression {}

## 5. ATTACK TYPES
variable use_default_attack_types {}
variable disabled_attack_types {}

## 6. SIGNATURE SELECTION BY ACCURACY
variable accuracy_signature_selection {}

## Optional violations view list
variable violations_list {}


#################################################
####### HTTP Load Balancer Variables #######
#################################################

variable delegated_dns_domain {}

#  IP Reputation Options 
variable enable_ip_reputation {}
variable ip_threat_categories {}


#################################################
####### Origin Pool Variables #######
#################################################

variable public_ip {}