variable "vpc_name"             { 
    description = "VPC name"
    type = string 
}
variable "vpc_cidr"             { 
    description = "VPC address space"
    type = string 
}
variable "mgmt_subnet_name"     { 
    description = "Management subnet name" 
    type = string 
}
variable "mgmt_cidr"            { 
    description = "Management subnet address prefix"
    type = string 
}
variable "external_subnet_name" { 
    description = "External subnet name"
    type = string 
}
variable "external_cidr"        { 
    description = "External subnet address prefix"
    type = string 
}
variable "internal_subnet_name" { 
    description = "Internal subnet name"
    type = string 
}
variable "internal_cidr"        { 
    description = "Internal subnet address prefix"
    type = string 
}
variable "availability_zone"    { 
    description = "Availability zone for all subnets"
    type = string 
}
