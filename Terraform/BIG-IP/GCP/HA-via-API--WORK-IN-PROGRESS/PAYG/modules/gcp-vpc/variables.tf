variable "mgmt_vpc_name" {
  description = "Management VPC network name"
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

variable "external_vpc_name" {
  description = "External VPC network name"
  type        = string
}

variable "external_subnet_name" {
  description = "External subnet name"
  type        = string
}

variable "external_cidr" {
  description = "External subnet CIDR"
  type        = string
}

variable "internal_vpc_name" {
  description = "Internal VPC network name"
  type        = string
}

variable "internal_subnet_name" {
  description = "Internal subnet name"
  type        = string
}

variable "internal_cidr" {
  description = "Internal subnet CIDR"
  type        = string
}

variable "region" {
  description = "GCP region for all subnets"
  type        = string
}
