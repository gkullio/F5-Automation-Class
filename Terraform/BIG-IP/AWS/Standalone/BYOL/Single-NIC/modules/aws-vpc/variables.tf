variable "vpc_name" {
  description = "VPC name"
  type        = string
}
variable "vpc_cidr" {
  description = "VPC address space"
  type        = string
}
variable "mgmt_subnet_name" {
  description = "Management subnet name"
  type        = string
}
variable "mgmt_cidr" {
  description = "Management subnet address prefix"
  type        = string
}
variable "availability_zone" {
  description = "Availability zone for the management subnet, e.g. us-east-1a. AZ-scoped and immutable -- changing it replaces the subnet."
  type        = string
}
