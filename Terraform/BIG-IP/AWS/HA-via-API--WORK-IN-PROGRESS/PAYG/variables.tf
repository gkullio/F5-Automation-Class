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

# Global Variables
variable "project_name" {
  description = "Grouping label stamped onto every resource via default_tags."
  type        = string
  default     = "bigip-aws-ha"
}

variable "resourceOwner" {}
variable "instance_size" {}

####### VPC — create new or use existing #######
variable "use_existing_vpc" {
  description = "Set to true to skip VPC/subnet creation and use existing IDs instead."
  type        = bool
  default     = false
}

# --- Used when use_existing_vpc = false (create new) ---
variable "vpc_name" { default = "" }
variable "vpc_cidr" { default = "" }
variable "mgmt_subnet_name" { default = "" }
variable "mgmt_cidr" { default = "" }
variable "external_subnet_name" { default = "" }
variable "external_cidr" { default = "" }
variable "internal_subnet_name" { default = "" }
variable "internal_cidr" { default = "" }

variable "availability_zone" {
  description = "Full AZ name, e.g. us-east-1a. Both BIG-IP instances deploy into this AZ."
  type        = string
}

# --- Used when use_existing_vpc = true (existing infrastructure) ---
variable "existing_vpc_id" {
  description = "ID of an existing VPC. Required when use_existing_vpc = true."
  type        = string
  default     = ""
}
variable "existing_mgmt_subnet_id" {
  description = "ID of an existing management subnet. Required when use_existing_vpc = true."
  type        = string
  default     = ""
}
variable "existing_external_subnet_id" {
  description = "ID of an existing external subnet. Required when use_existing_vpc = true."
  type        = string
  default     = ""
}
variable "existing_internal_subnet_id" {
  description = "ID of an existing internal subnet. Required when use_existing_vpc = true."
  type        = string
  default     = ""
}

####### Module BIG-IP VM #######
variable "vm_name_1" {
  description = "Name tag for the primary BIG-IP instance."
  type        = string
  default     = ""
}
variable "vm_name_2" {
  description = "Name tag for the secondary BIG-IP instance."
  type        = string
  default     = ""
}
variable "instance_prefix" {}

variable "external_gw" {
  description = "Default gateway for the external subnet (first usable IP in the CIDR, e.g. 10.245.10.1). Becomes the TMM default route."
  type        = string
}

variable "cfe_label" {
  description = "Value for the f5_cloud_failover_label tag. Must match across both BIG-IPs and all tagged AWS resources."
  type        = string
  default     = "bigip-ha-cfe"
}

variable "create_external_eips" {
  description = "true = create EIPs on management and external interfaces. false = management EIPs only."
  type        = bool
  default     = true
}

####### Networking source address lists #######
variable "vpnMgmtSrcAddr" {}
variable "REtrafficSrcAddr" {}

# BIG-IP VE specific variables
variable "bigip_hostname_1" {
  description = "Hostname for the primary BIG-IP (short name, without domain suffix)."
  type        = string
}
variable "bigip_hostname_2" {
  description = "Hostname for the secondary BIG-IP (short name, without domain suffix)."
  type        = string
}
variable "ssh_publickey" {}
variable "f5_username" {}
variable "f5_username_2" {}
variable "f5_password" {}
variable "dns_suffix" {}
variable "dns_server" {}
variable "ntp_server" {}
variable "timezone" {}

variable "f5_ami_search_name" {
  description = "Wildcard match for the BIG-IP AMI name."
  type        = string
  default     = "*BIGIP-17*PAYG-Best Plus 25Mbps*"
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
