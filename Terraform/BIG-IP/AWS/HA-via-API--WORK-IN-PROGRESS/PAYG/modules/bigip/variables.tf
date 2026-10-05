variable "aws_region" {
  description = "Region the instances land in. Passed into the onboarding templates as a static value so the BIG-IPs never have to query instance metadata for it."
  type        = string
}
variable "resourceOwner" {}
variable "adminSrcAddr" {
  type = list(string)
}
variable "REtrafficSrcAddr" {
  type = list(string)
}
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
variable "vpc_id" {}
variable "vpc_cidr" {
  description = "VPC CIDR block, used in the internal security group to allow all intra-VPC traffic."
  type        = string
}
variable "mgmt_subnet_id" {}
variable "external_subnet_id" {}
variable "internal_subnet_id" {}
variable "instance_prefix" {}

variable "external_gw" {
  description = "Default gateway for the external subnet (first usable IP in the CIDR, e.g. 10.245.10.1). Becomes the TMM default route in the DO declaration."
  type        = string
}

variable "ssh_publickey" {}
variable "bigip_hostname_1" {
  description = "Hostname for the primary BIG-IP (short name, without domain suffix)."
  type        = string
}
variable "bigip_hostname_2" {
  description = "Hostname for the secondary BIG-IP (short name, without domain suffix)."
  type        = string
}

variable "instance_size" {}
variable "INIT_URL" {}

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

variable "cfe_rpm_file" {
  description = "Filename of the Cloud Failover Extension RPM in modules/bigip/rpm_files/."
  type        = string
  default     = "f5-cloud-failover-2.5.1-1.noarch.rpm"

  validation {
    condition     = can(regex("^f5-cloud-failover-.+\\.noarch\\.rpm$", var.cfe_rpm_file))
    error_message = "cfe_rpm_file must match f5-cloud-failover-<version>-<build>.noarch.rpm."
  }
}

variable "create_external_eips" {
  description = "true = create EIPs on both management and external interfaces. false = management EIPs only (external interfaces stay private)."
  type        = bool
  default     = true
}

variable "cfe_label" {
  description = "Value for the f5_cloud_failover_label tag applied to all HA resources (ENIs, EIPs, S3 bucket). Must be consistent across both BIG-IPs and all tagged AWS resources."
  type        = string
  default     = "bigip-ha-cfe"
}

variable "libs_dir" {
  description = "Directory on the BIG-IP to download the A&O Toolchain into"
  default     = "/config/cloud/aws/node_modules"
  type        = string
}
variable "custom_user_data" {
  description = "Provide a custom bash script or cloud-init script the BIG-IP will run on creation"
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# AMI selection
# ---------------------------------------------------------------------------

variable "f5_ami_search_name" {
  type        = string
  default     = "*BIGIP-17*PAYG-Best Plus 25Mbps*"
  description = <<-EOD
Wildcard match against the AMI name. Find the exact names available in your
region with:

aws ec2 describe-images \
  --owners aws-marketplace \
  --filters "Name=name,Values=*BIGIP-17*PAYG*" \
  --query 'Images[].[Name,ImageId,CreationDate]' --output table

The default targets the PAYG Best Plus 25Mbps image.
For BYOL, search for "*BIGIP-17*BYOL*" instead and add a regKey to the DO
declaration in f5_onboard.tmpl.
EOD
}

variable "f5_ami_owner" {
  type        = string
  default     = "aws-marketplace"
  description = "AMI owner filter. \"aws-marketplace\" is the portable alias; 679593333241 is F5's published owner ID if you want it pinned."
}

variable "root_volume_size" {
  description = "Root volume size in GiB. Leave null to inherit the AMI's own snapshot size."
  type        = number
  default     = null
}

variable "root_volume_encrypted" {
  description = "Encrypt the root EBS volume at launch."
  type        = bool
  default     = true
}

variable "imds_http_tokens" {
  description = "IMDSv2 enforcement. \"required\" is correct for this build because the onboarding template takes hostname and region as static template values and never calls the metadata service over plain HTTP."
  type        = string
  default     = "required"

  validation {
    condition     = contains(["required", "optional"], var.imds_http_tokens)
    error_message = "imds_http_tokens must be \"required\" or \"optional\"."
  }
}

variable "dns_server" {
  description = "The DNS server to use for the VM."
}
variable "dns_suffix" {
  description = "The DNS suffix to use for the VM."
}
variable "ntp_server" {
  description = "The NTP server to use for the VM."
}
variable "timezone" {
  type        = string
  default     = "UTC"
  description = "Olson time zone, e.g. UTC, US/Pacific, US/Eastern."
}
variable "f5_username" {
  type        = string
  description = "The username for the BIG-IP VE."
}
variable "f5_password" {
  type        = string
  description = "The password for the BIG-IP VE."
  sensitive   = true
}
variable "f5_username_2" {
  type        = string
  description = "The second username for the BIG-IP VE."
}
