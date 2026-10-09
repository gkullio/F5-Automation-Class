# AWS targeting
#
# No access key / secret key here on purpose -- see the note above the aws
# provider block in providers.tf. Only the region and an optional local SSO
# profile name.

variable "aws_region" {
  description = "AWS region to deploy into, e.g. us-east-1. The Azure analog of `location`."
  type        = string
}
variable "aws_profile" {
  description = "Named profile from ~/.aws/config for local runs, e.g. the IAM Identity Center profile you `aws sso login` to. Leave empty in GitHub Actions so the OIDC environment credentials are used instead."
  type        = string
  default     = ""
}

# Azure Credentials
#
# Still needed: the kulland.info DNS zone, the wildcard-cert Key Vault and the
# shared artifact store all live in Azure. See README.md.
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "subscription_id" {}

# Global Variables
#
# There is no rg_name equivalent -- AWS has no resource group. project_name
# replaces it as the grouping label, applied through provider default_tags.
variable "project_name" {
  description = "Grouping label stamped onto every resource via default_tags. Stands in for the Azure resource group, and is what you filter the console on to find strays."
  type        = string
  default     = "bigip-aws-1nic"
}

variable "resourceOwner" {}
variable "ownerEmail" {}
variable "instance_size" {}


####### Module aws-vpc #######

variable "vpc_name" {}
variable "vpc_cidr" {}
variable "mgmt_subnet_name" {}
variable "mgmt_cidr" {}

variable "availability_zone" {
  description = "Full AZ name, e.g. us-east-1a -- not the bare number Azure takes. AWS subnets are AZ-scoped, so this pins the subnet, and the instance follows the subnet."
  type        = string
}

####### Module BIG-IP VM #######

variable "vm_name" {}
variable "instance_prefix" {}

####### Networking source address lists  #######

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

# Replaces the Azure f5_product_name / f5_image_name / f5_version trio. AWS has
# no publisher/offer/sku split -- there is one flat AMI name to match on.
variable "f5_ami_search_name" {
  description = "Wildcard match for the BIG-IP AMI name. Confirm the exact names in your region with: aws ec2 describe-images --owners aws-marketplace --filters \"Name=name,Values=*BIGIP-17*PAYG*\" --query 'Images[].[Name,ImageId,CreationDate]' --output table"
  type        = string
  default     = "*BIGIP-17*PAYG-Best Plus 25Mbps*"
}

variable "f5_ami_owner" {
  description = "AMI owner. \"aws-marketplace\" is the portable alias; F5's own published account ID is 679593333241 if you need to pin it harder."
  type        = string
  default     = "aws-marketplace"
}

variable "dns_record_name" {
  description = "A-record hostname in kulland.info. MUST differ from the Azure single-NIC project's record ('bigip-1nic') or the two deployments fight over the same name."
  type        = string
  default     = "bigip-1nic-aws"
}

variable "INIT_URL" {
  type    = string
  default = "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/2.0.3/f5-bigip-runtime-init-2.0.3-1.gz.run"
}

variable "key_vault_name" {
  description = "Name of the existing Key Vault that stores the wildcard certificate"
  type        = string
}

variable "key_vault_rg" {
  description = "Resource group containing the Key Vault"
  type        = string
  default     = "kulland-house-keys"
}

####### CrowdStrike Falcon sensor #######

variable "crowdstrike_enabled" {
  description = <<-EOD
Install the CrowdStrike Falcon sensor during onboarding.

Threaded to two places, both from this one flag: module "artifacts", which
decides whether the sensor blobs are resolved and a SAS minted at all, and the
bigip module, which gates the install block in f5_onboard.tmpl. False means no
SAS token in state, no CID in the instance's user_data, and none of the cs_*
variables below need values.

Defaults true. A security sensor that silently does not install is a worse
failure than an apply that stops to ask for a CID, so opting out is explicit.
EOD
  type    = bool
  default = true
}

variable "cs_cid" {
  description = "CrowdStrike Customer ID: 32 hex characters, a hyphen, then the 2-character checksum. Required when crowdstrike_enabled is true."
  type        = string
  sensitive   = true
  default     = ""

  # Empty has to pass so crowdstrike_enabled = false does not need a CID.
  # Terraform only allows a validation block to reference its own variable
  # before 1.9, so "enabled but empty" is caught by a precondition on
  # aws_instance.bigip instead -- still at plan time, just not here.
  validation {
    condition     = var.cs_cid == "" || can(regex("^[0-9A-Fa-f]{32}-[0-9A-Fa-f]{2}$", var.cs_cid))
    error_message = "cs_cid must be 32 hex characters, a hyphen, then a 2-character checksum (e.g. 1234567890ABCDEF1234567890ABCDEF-XY), or empty when crowdstrike_enabled = false."
  }
}

variable "cs_tags_bigip" {
  description = "Falcon sensor grouping tags for the BIG-IP. Comma-separated; tags may not contain spaces or commas, so key/value pairs are encoded with '/'. Empty leaves the install script's own defaults in place."
  type        = string
  default     = ""
}

variable "cs_provisioning_token" {
  description = "Falcon installation token. Leave empty unless the CID requires one."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cs_sas_validity_hours" {
  description = "Lifetime of the read-only SAS token the instance uses to pull the sensor packages. Measured from the time_static.cs_sas timestamp recorded in state, not from each apply, so rebuilds keep working until it expires."
  type        = number
  default     = 8760 # 1 year
}

####### Artifact store #######
#
# The storage account, containers and blob names all live in
# ../../modules/artifact-lookup. Override its variables in the
# module "artifacts" block in main.tf if this project ever needs to point at a
# different store or a different RPM version.
