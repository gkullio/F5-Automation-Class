variable "gcp_region" {
  description = "GCP region."
  type        = string
}
variable "gcp_zone" {
  description = "GCP zone for the instances."
  type        = string
}
variable "gcp_project_id" {
  description = "GCP project ID (needed for IAM bindings)."
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

# Per-instance names
variable "vm_name_1" {
  description = "Name for the primary BIG-IP instance."
  type        = string
}
variable "vm_name_2" {
  description = "Name for the secondary BIG-IP instance."
  type        = string
}
variable "bigip_hostname_1" {
  description = "Hostname for the primary BIG-IP."
  type        = string
}
variable "bigip_hostname_2" {
  description = "Hostname for the secondary BIG-IP."
  type        = string
}

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

variable "machine_type" {
  description = "GCP machine type. Must support 3+ NICs (>= 8 vCPUs)."
  type        = string
  default     = "n2-standard-8"
}
variable "INIT_URL" {}

# ---------------------------------------------------------------------------
# Cloud Failover Extension
# ---------------------------------------------------------------------------

variable "cfe_label" {
  description = "Value for the f5_cloud_failover_label used by CFE to discover peers, state bucket, and managed resources."
  type        = string
  default     = "bigip-gcp-ha"
}

variable "cfe_rpm_file" {
  description = "Filename of the Cloud Failover Extension RPM in modules/bigip/rpm_files/."
  type        = string
  default     = "f5-cloud-failover-2.5.1-1.noarch.rpm"

  validation {
    condition     = can(regex("^f5-cloud-failover-.+\\.noarch\\.rpm$", var.cfe_rpm_file))
    error_message = "cfe_rpm_file must match f5-cloud-failover-<version>-<build>.noarch.rpm."
  }
}

# ---------------------------------------------------------------------------
# Extension RPMs
# ---------------------------------------------------------------------------

variable "do_rpm_file" {
  description = "Filename of the Declarative Onboarding RPM in modules/bigip/rpm_files/."
  type        = string
  default     = "f5-declarative-onboarding-1.49.0-14.noarch.rpm"

  validation {
    condition     = can(regex("^f5-declarative-onboarding-.+\\.noarch\\.rpm$", var.do_rpm_file))
    error_message = "do_rpm_file must match f5-declarative-onboarding-<version>-<build>.noarch.rpm."
  }
}

variable "as3_rpm_file" {
  description = "Filename of the AS3 RPM in modules/bigip/rpm_files/."
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
