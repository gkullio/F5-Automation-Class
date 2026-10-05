variable "gcp_region" {
  description = "GCP region."
  type        = string
}
variable "gcp_zone" {
  description = "GCP zone for the instance."
  type        = string
}
variable "resourceOwner" {}
variable "project_label" {
  description = "Value for the 'project' label on GCP resources."
  type        = string
}
variable "adminSrcAddr" {
  type = list(string)
}
variable "REtrafficSrcAddr" {
  type = list(string)
}
variable "vm_name" {}

# VPC self-links (one per VPC network, for firewall rules)
variable "mgmt_vpc_self_link"     { type = string }
variable "external_vpc_self_link" { type = string }
variable "internal_vpc_self_link" { type = string }

# Subnet self-links (one per interface)
variable "mgmt_subnet_self_link"     { type = string }
variable "external_subnet_self_link" { type = string }
variable "internal_subnet_self_link" { type = string }

variable "instance_prefix" {}

variable "external_gw" {
  description = "Default gateway for the external subnet (first usable IP in the CIDR, e.g. 10.245.10.1). Becomes the TMM default route."
  type        = string
}

variable "ssh_publickey" {}
variable "bigip-hostname" {}

variable "machine_type" {
  description = "GCP machine type. Must support 3+ NICs (>= 8 vCPUs)."
  type        = string
  default     = "n2-standard-8"
}
variable "INIT_URL" {}

variable "do_rpm_file" {
  description = "Filename of the Declarative Onboarding RPM in modules/bigip/rpm_files/. The version is extracted by splitting on hyphens (index 3)."
  type        = string
  default     = "f5-declarative-onboarding-1.49.0-14.noarch.rpm"

  validation {
    condition     = can(regex("^f5-declarative-onboarding-.+\\.noarch\\.rpm$", var.do_rpm_file))
    error_message = "do_rpm_file must match f5-declarative-onboarding-<version>-<build>.noarch.rpm."
  }
}

variable "as3_rpm_file" {
  description = "Filename of the AS3 RPM in modules/bigip/rpm_files/. The version is extracted by splitting on hyphens (index 2)."
  type        = string
  default     = "f5-appsvcs-3.57.0-13.noarch.rpm"

  validation {
    condition     = can(regex("^f5-appsvcs-.+\\.noarch\\.rpm$", var.as3_rpm_file))
    error_message = "as3_rpm_file must match f5-appsvcs-<version>-<build>.noarch.rpm."
  }
}

variable "custom_user_data" {
  type    = string
  default = null
}
variable "script_name" {
  default = "f5_onboard"
}

# ---------------------------------------------------------------------------
# Image selection
# ---------------------------------------------------------------------------

variable "byol_license" {
  description = "F5 BIG-IP BYOL registration key. Applied via the myLicense DO declaration block at onboard time."
  type        = string
  sensitive   = true
}

variable "f5_image_name" {
  description = <<-EOD
Exact BIG-IP BYOL image name from the f5_image_project. Find available images:

gcloud compute images list --project f5-7626-networks-public \
  --filter="name~bigip-17.*byol" --sort-by=~creationTimestamp --limit=10

The default targets the BYOL all-modules image.
EOD
  type        = string
  default     = "f5-bigip-17-1-2-1-0-0-2-byol-all-modules-2boot-loc"
}

variable "f5_image_project" {
  type    = string
  default = "f5-7626-networks-public"
}

variable "boot_disk_size" {
  type    = number
  default = null
}

variable "boot_disk_type" {
  type    = string
  default = "pd-ssd"
}

variable "dns_server" {}
variable "dns_suffix" {}
variable "ntp_server" {}
variable "timezone" {
  type    = string
  default = "UTC"
}
variable "f5_username" {
  type = string
}
variable "f5_password" {
  type      = string
  sensitive = true
}
variable "f5_username_2" {
  type = string
}

locals {
  owner_label = replace(replace(replace(lower(var.resourceOwner), "@", "-"), ".", "-"), " ", "-")
}
