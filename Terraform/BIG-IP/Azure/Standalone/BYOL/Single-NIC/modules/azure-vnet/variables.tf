variable "vnet_name" {
  description = "VNet name"
  type        = string
}
variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}
variable "location" {
  description = "Azure region"
  type        = string
}
variable "vnet_address_space" {
  description = "VNet address space"
  type        = string
}
variable "mgmt_subnet_name" {
  description = "Management subnet name"
  type        = string
}
variable "mgmt_address_space" {
  description = "Management subnet address prefix"
  type        = string
}
