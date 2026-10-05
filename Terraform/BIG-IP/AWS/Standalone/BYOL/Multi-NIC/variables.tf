# AWS targeting
variable "aws_region" {
  description = "AWS region to deploy into, e.g. us-east-1."
  type        = string
}
variable "aws_profile" {
  description = "Named profile from ~/.aws/config for local runs. Leave empty in GitHub Actions so the OIDC environment credentials are used instead."
  type        = string
  default     = ""
}

# Azure Credentials
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "subscription_id" {}

# Global Variables
variable "project_name" {
  description = "Grouping label stamped onto every resource via default_tags."
  type        = string
  default     = "bigip-aws-3nic"
}

variable "resourceOwner" {}
variable "instance_size" {}

####### Module aws-vpc #######
variable "vpc_name" {}
variable "vpc_cidr" {}
variable "mgmt_subnet_name" {}
variable "mgmt_cidr" {}
variable "external_subnet_name" {}
variable "external_cidr" {}
variable "internal_subnet_name" {}
variable "internal_cidr" {}

variable "availability_zone" {
  description = "Full AZ name, e.g. us-east-1a"
  type        = string
}

####### Module BIG-IP VM #######
variable "vm_name" {}
variable "instance_prefix" {}

variable "external_gw" {
  description = "Default gateway for the external subnet (first usable IP in the CIDR, e.g. 10.245.10.1). Becomes the TMM default route."
  type        = string
}

####### Networking source address lists #######
variable "vpnMgmtSrcAddr" {}
variable "REtrafficSrcAddr" {}

# BIG-IP VE specific variables
variable "bigip-hostname" {}
variable "ssh_publickey" {}
variable "f5_username" {}
variable "f5_username_2" {}
variable "f5_password" {}
variable "dns_suffix" {}
variable "dns_server" {}
variable "ntp_server" {}
variable "timezone" {}
variable "script_name" {}

variable "byol_license" {
  description = "F5 BIG-IP BYOL registration key. Applied via the myLicense DO declaration block at onboard time."
  type        = string
  sensitive   = true
}

variable "f5_ami_search_name" {
  description = "Wildcard match for the BIG-IP AMI name."
  type        = string
  default     = "*BIGIP-17*BYOL*"
}

variable "f5_ami_owner" {
  description = "AMI owner."
  type        = string
  default     = "aws-marketplace"
}

variable "INIT_URL" {
  type    = string
  default = "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/2.0.3/f5-bigip-runtime-init-2.0.3-1.gz.run"
}


