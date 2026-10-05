variable "aws_region" {
  description = "Region the instance lands in. Passed into the onboarding template as a static value so the BIG-IP never has to query instance metadata for it."
  type        = string
}
variable "resourceOwner" {}
variable "adminSrcAddr" {
  type = list(string)
}
variable "REtrafficSrcAddr" {
  type = list(string)
}
variable "vm_name" {}
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
variable "bigip-hostname" {}

variable "instance_size" {}
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
variable "script_name" {
  default = "f5_onboard"
}

# ---------------------------------------------------------------------------
# AMI selection
# ---------------------------------------------------------------------------

variable "byol_license" {
  description = "F5 BIG-IP BYOL registration key. Applied via the myLicense DO declaration block at onboard time."
  type        = string
  sensitive   = true
}

variable "f5_ami_search_name" {
  type        = string
  default     = "*BIGIP-17*BYOL*"
  description = <<-EOD
Wildcard match against the AMI name. Find the exact names available in your
region with:

aws ec2 describe-images \
  --owners aws-marketplace \
  --filters "Name=name,Values=*BIGIP-17*BYOL*" \
  --query 'Images[].[Name,ImageId,CreationDate]' --output table

The default targets the BYOL all-modules image.

Keep the patch level wildcarded — F5 removes old AMIs, which breaks plans
that pin an exact version.
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

