variable "vpc_name" {
  description = "VPC network name"
  type        = string
}

variable "mgmt_subnet_name" {
  description = "Management subnet name"
  type        = string
}

variable "mgmt_cidr" {
  description = "Management subnet CIDR"
  type        = string
}

variable "region" {
  description = "GCP region for the subnet"
  type        = string
}
