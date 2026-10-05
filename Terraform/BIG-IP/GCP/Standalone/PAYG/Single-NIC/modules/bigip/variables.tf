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
variable "vpc_self_link" {
  description = "Self-link of the VPC network for firewall rules."
  type        = string
}
variable "mgmt_subnet_self_link" {
  description = "Self-link of the management subnet."
  type        = string
}
variable "instance_prefix" {}

variable "ssh_publickey" {}
variable "bigip-hostname" {}

variable "machine_type" {
  description = "GCP machine type (the AWS instance_size equivalent)."
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
  description = "Provide a custom startup script."
  type        = string
  default     = null
}
variable "script_name" {
  default = "f5_onboard"
}

# ---------------------------------------------------------------------------
# Image selection
# ---------------------------------------------------------------------------

variable "f5_image_name" {
  description = <<-EOD
Exact BIG-IP image name from the f5_image_project. Find available images:

gcloud compute images list --project f5-7626-networks-public \
  --filter="name~bigip" --sort-by=~creationTimestamp --limit=10
EOD
  type        = string
  default     = "f5-bigip-17-1-2-1-0-0-2-payg-best-plus-25mbps"
}

variable "f5_image_project" {
  description = "GCP project containing F5 BIG-IP images."
  type        = string
  default     = "f5-7626-networks-public"
}

variable "boot_disk_size" {
  description = "Boot disk size in GB. Null inherits the image default."
  type        = number
  default     = null
}

variable "boot_disk_type" {
  description = "Boot disk type."
  type        = string
  default     = "pd-ssd"
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