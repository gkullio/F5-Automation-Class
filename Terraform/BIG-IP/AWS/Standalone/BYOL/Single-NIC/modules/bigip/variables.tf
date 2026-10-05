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
variable "mgmt_subnet_id" {}
variable "instance_prefix" {}

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
#
# Replaces the Azure image_publisher / f5_product_name / f5_image_name /
# f5_version set. AWS exposes one flat name string instead.
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

Keep the patch level wildcarded -- F5 removes old AMIs, which breaks plans
that pin an exact version.
EOD
}

variable "f5_ami_owner" {
  type        = string
  default     = "aws-marketplace"
  description = "AMI owner filter. \"aws-marketplace\" is the portable alias; 679593333241 is F5's published owner ID if you want it pinned."
}

variable "root_volume_size" {
  description = "Root volume size in GiB. Leave null to inherit the AMI's own snapshot size, which is the safe default -- EBS can grow a volume but never shrink one, so any value below the AMI's snapshot size fails the apply. The Azure projects pin 100 GiB; check the AMI before matching that here."
  type        = number
  default     = null
}

variable "root_volume_encrypted" {
  description = "Encrypt the root EBS volume at launch. Fine for the F5 Marketplace AMIs, but if an apply ever fails complaining about encryption on a product-code-bearing AMI, set this false and encrypt via an EBS-default-encryption policy instead."
  type        = bool
  default     = true
}

variable "imds_http_tokens" {
  description = "IMDSv2 enforcement. \"required\" is correct for this build because the onboarding template takes hostname and region as static template values and never calls the metadata service over plain HTTP. Switch to \"optional\" only if you add a runtime-init `type: url` parameter pointed at 169.254.169.254."
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
  description = "If you would like to change the time zone the BIG-IP uses, enter the time zone you want to use. This is based on the tz database found in /usr/share/zoneinfo. Example values: UTC, US/Pacific, US/Eastern, Europe/London or Asia/Singapore."
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

####### CrowdStrike Falcon sensor #######

variable "crowdstrike_enabled" {
  description = "Install the Falcon sensor during onboarding. False drops the whole CrowdStrike block out of the rendered user_data -- see the templatefile `if` in f5_onboard.tmpl -- so none of the cs_* values below need to be set, and no SAS token or CID is written into the instance attribute. Must match the flag on module \"artifacts\" in the root, which is what resolves the blob URLs; aws_instance has a precondition that catches a mismatch at plan time."
  type        = bool
  default     = true
}

# The three URL/token variables come straight from module "artifacts", whose
# cs_* outputs are null when its own crowdstrike_enabled is false. Hence the
# null defaults rather than "" -- the value arrives as null, not empty.

variable "cs_rpm_url" {
  description = "Bare URL of the Falcon sensor RPM in the shared artifact store. cs_sas_token is appended to it here; the module does not upload the package itself. Null when crowdstrike_enabled is false."
  type        = string
  default     = null
}

variable "cs_script_url" {
  description = "Bare URL of bigip-cs-install.sh in the shared artifact store. cs_sas_token is appended to it here. Null when crowdstrike_enabled is false."
  type        = string
  default     = null
}

variable "cs_sas_token" {
  description = "Read-only SAS token (leading '?' included) appended to the blob URLs so the BIG-IP can pull them from the private container. Null when crowdstrike_enabled is false."
  type        = string
  sensitive   = true
  default     = null
}

variable "cs_cid" {
  description = "CrowdStrike Customer ID. Passed to the install script as the CS_CID environment variable. Required when crowdstrike_enabled is true; ignored otherwise."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cs_tags" {
  description = "Falcon sensor grouping tags. Passed as the TAGS environment variable, which the script prefers over its own hardcoded default. Empty leaves the script's defaults in place."
  type        = string
  default     = ""
}

variable "cs_provisioning_token" {
  description = "Falcon installation token. Empty unless the CID requires one."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cs_sensor_path" {
  description = "Where cloud-init stages the RPM on the BIG-IP. Must be under /shared so it survives into other boot locations; this is the script's own default."
  type        = string
  default     = "/shared/images/falcon-sensor.rpm"
}
