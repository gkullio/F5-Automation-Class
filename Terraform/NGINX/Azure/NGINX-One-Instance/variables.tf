variable "resource_group_location" {
  type        = string
  description = "Location of the resource group."
}
variable "resource_group_name_prefix" {
  type        = string
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}
variable "vnet_name" {
  type        = string
  description = "Name of the virtual network."
}
variable "vnet_address_space" {
  type        = string
  description = "The CIDR block for the virtual network."
}
variable "mgmt_subnet_name" {
  type        = string
  description = "Name of the management subnet."
}
variable "mgmt_address_space" {
  type        = string
  description = "The CIDR block for the management subnet."
}
variable "int_subnet_name" {
  type        = string
  description = "Name of the internal subnet."
}
variable "int_address_space" {
  type        = string
  description = "The CIDR block for the internal subnet."
}
variable "username" {
  type        = string
  description = "The username for the local account that will be created on the new VM."
}
variable "client_id" {
  type        = string
  description = "The client ID for the Service Principal."  
}
variable "client_secret" {
  type        = string
  description = "The client secret for the Service Principal."
}
variable "tenant_id" {
  type        = string
  description = "The tenant ID for the Service Principal."  
}
variable "subscription_id" {
  type        = string
  description = "The subscription ID for the Azure subscription."    
}
variable "password" {
  type        = string
  description = "The password for the local account that will be created on the new VM."
}
variable "adminSrcAddr" {
  type        = list(string)
  description = "Allowed Admin source IP prefix"
  #Recommend using icanhazip.com to get your public IP address
  #Recommend against 0.0.0.0/0 for security reasons  
}
variable "hostname" {
  type        = string
  description = "Hostname of the ubuntu VM"
}
variable "instance_size" {
  type        = string
  description = "The size of the VM instance."  
}
variable "resourceOwner" {
  type        = string
  description = "The owner of the resources."  
}
variable "dp_token" {
  type        = string
  description = "The NGINX Data Plane token."
}