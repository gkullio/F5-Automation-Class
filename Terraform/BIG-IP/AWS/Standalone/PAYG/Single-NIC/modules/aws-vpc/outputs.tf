output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.vpc.id
}

output "mgmt_subnet_id" {
  description = "The ID of the management subnet"
  value       = aws_subnet.mgmt.id
}

output "internet_gateway_id" {
  description = "The ID of the internet gateway. Exported mainly so a missing egress path is visible in `terraform output`."
  value       = aws_internet_gateway.igw.id
}
