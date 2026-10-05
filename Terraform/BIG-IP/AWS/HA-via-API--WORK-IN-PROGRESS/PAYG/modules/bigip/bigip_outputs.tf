# ---- Primary (bigip1) outputs ----
output "bigip1_management_public_ip"  { value = aws_eip.mgmt_1.public_ip }
output "bigip1_management_private_ip" { value = aws_instance.bigip1.private_ip }
output "bigip1_external_public_ip"    { value = var.create_external_eips ? aws_eip.external_1[0].public_ip : "" }
output "bigip1_external_private_ip"   { value = aws_network_interface.external_1.private_ip }
output "bigip1_internal_private_ip"   { value = aws_network_interface.internal_1.private_ip }
output "bigip1_instance_id"           { value = aws_instance.bigip1.id }

# ---- Secondary (bigip2) outputs ----
output "bigip2_management_public_ip"  { value = aws_eip.mgmt_2.public_ip }
output "bigip2_management_private_ip" { value = aws_instance.bigip2.private_ip }
output "bigip2_external_public_ip"    { value = var.create_external_eips ? aws_eip.external_2[0].public_ip : "" }
output "bigip2_external_private_ip"   { value = aws_network_interface.external_2.private_ip }
output "bigip2_internal_private_ip"   { value = aws_network_interface.internal_2.private_ip }
output "bigip2_instance_id"           { value = aws_instance.bigip2.id }

# ---- Shared outputs ----
output "vip_public_ip"    { value = var.create_external_eips ? aws_eip.vip[0].public_ip : "" }
output "ami_id"           { value = data.aws_ami.f5.id }
output "ami_name"         { value = data.aws_ami.f5.name }
output "cfe_state_bucket" { value = aws_s3_bucket.cfe_state.id }

output "mgmt_security_group_id"     { value = aws_security_group.mgmt.id }
output "external_security_group_id" { value = aws_security_group.external.id }
output "internal_security_group_id" { value = aws_security_group.internal.id }
