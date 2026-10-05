variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources in (e.g. us-east-1)."
}
variable "aws_access_key" {
  type        = string
  description = "AWS access key. Leave null to use environment variables (AWS_ACCESS_KEY_ID) or ~/.aws/credentials."
  default     = null
  sensitive   = true
}
variable "aws_secret_key" {
  type        = string
  description = "AWS secret key. Leave null to use environment variables (AWS_SECRET_ACCESS_KEY) or ~/.aws/credentials."
  default     = null
  sensitive   = true
}
variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC."
}
variable "mgmt_subnet_cidr" {
  type        = string
  description = "The CIDR block for the management subnet."
}
variable "int_subnet_cidr" {
  type        = string
  description = "The CIDR block for the internal subnet."
}
variable "username" {
  type        = string
  description = "The username for the local account that will be created on the new VM."
}
variable "adminSrcAddr" {
  type        = list(string)
  description = "Allowed Admin source IP prefixes in CIDR notation (e.g. [\"203.0.113.10/32\"])"
}
variable "hostname" {
  type        = string
  description = "Hostname of the ubuntu VM"
}
variable "instance_type" {
  type        = string
  description = "The EC2 instance type (e.g. t3.xlarge)."
}
variable "resourceOwner" {
  type        = string
  description = "The owner of the resources (used in tags)."
}
