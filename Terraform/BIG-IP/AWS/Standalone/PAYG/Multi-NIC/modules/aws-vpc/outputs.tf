output "vpc_id"              { value = aws_vpc.vpc.id }
output "mgmt_subnet_id"     { value = aws_subnet.mgmt.id }
output "external_subnet_id" { value = aws_subnet.external.id }
output "internal_subnet_id" { value = aws_subnet.internal.id }
output "internet_gateway_id" { value = aws_internet_gateway.igw.id }
