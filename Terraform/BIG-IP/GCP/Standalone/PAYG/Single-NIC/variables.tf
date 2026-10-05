# GCP targeting
variable "gcp_project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}
variable "gcp_region" {
  description = "GCP region, e.g. us-east1."
  type        = string
}
variable "gcp_zone" {
  description = "GCP zone, e.g. us-east1-b."
  type        = string
}

# Azure Credentials (for Key Vault, DNS, artifact store)
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "subscription_id" {}

# Global Variables
variable "project_name" {
  description = "Grouping label stamped onto every resource."
  type        = string
  default     = "bigip-gcp-1nic"
}

variable "resourceOwner" {}
variable "machine_type" {
  description = "GCP machine type."
  type        = string
  default     = "n2-standard-8"
}

####### Module gcp-vpc #######
variable "vpc_name" {}
variable "mgmt_subnet_name" {}
variable "mgmt_cidr" {}

####### Module BIG-IP VM #######
variable "vm_name" {}
variable "instance_prefix" {}

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

variable "f5_image_name" {
  description = "Exact BIG-IP image name from f5_image_project."
  type        = string
  default     = "f5-bigip-17-1-2-1-0-0-2-payg-best-plus-25mbps"
}

variable "f5_image_project" {
  description = "GCP project containing F5 BIG-IP images."
  type        = string
  default     = "f5-7626-networks-public"
}

variable "INIT_URL" {
  type    = string
  default = "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/2.0.3/f5-bigip-runtime-init-2.0.3-1.gz.run"
}

variable "terraform_sa_email" {
  type        = string
  description = "Service account email to impersonate"
}
