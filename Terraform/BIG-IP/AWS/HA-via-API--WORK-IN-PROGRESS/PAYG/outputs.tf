# ---- Primary BIG-IP ----
output "BIG-IP1-SSH" {
  value = "ssh admin@${module.bigip.bigip1_management_public_ip}"
}

output "BIG-IP1-UI" {
  value = "https://${module.bigip.bigip1_management_public_ip}"
}

output "BIG-IP1-External" {
  value = module.bigip.bigip1_external_public_ip != "" ? "https://${module.bigip.bigip1_external_public_ip}" : "(no external EIP)"
}

output "bigip1_ec2_console_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/ec2/home?region=${var.aws_region}#InstanceDetails:instanceId=${module.bigip.bigip1_instance_id}"
}

output "bigip1_onboarding_log_tail" {
  value = "ssh -t admin@${module.bigip.bigip1_management_public_ip} 'run util bash -c \"tail -f /var/log/cloud/startup-script.log\"'"
}

output "bigip1_console_output_cmd" {
  value = "aws ec2 get-console-output --instance-id ${module.bigip.bigip1_instance_id} --region ${var.aws_region} --output text"
}

output "bigip1_management_private_ip" {
  value = module.bigip.bigip1_management_private_ip
}

output "bigip1_external_private_ip" {
  value = module.bigip.bigip1_external_private_ip
}

output "bigip1_internal_private_ip" {
  value = module.bigip.bigip1_internal_private_ip
}

# ---- Secondary BIG-IP ----
output "BIG-IP2-SSH" {
  value = "ssh admin@${module.bigip.bigip2_management_public_ip}"
}

output "BIG-IP2-UI" {
  value = "https://${module.bigip.bigip2_management_public_ip}"
}

output "BIG-IP2-External" {
  value = module.bigip.bigip2_external_public_ip != "" ? "https://${module.bigip.bigip2_external_public_ip}" : "(no external EIP)"
}

output "bigip2_ec2_console_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/ec2/home?region=${var.aws_region}#InstanceDetails:instanceId=${module.bigip.bigip2_instance_id}"
}

output "bigip2_onboarding_log_tail" {
  value = "ssh -t admin@${module.bigip.bigip2_management_public_ip} 'run util bash -c \"tail -f /var/log/cloud/startup-script.log\"'"
}

output "bigip2_console_output_cmd" {
  value = "aws ec2 get-console-output --instance-id ${module.bigip.bigip2_instance_id} --region ${var.aws_region} --output text"
}

output "bigip2_management_private_ip" {
  value = module.bigip.bigip2_management_private_ip
}

output "bigip2_external_private_ip" {
  value = module.bigip.bigip2_external_private_ip
}

output "bigip2_internal_private_ip" {
  value = module.bigip.bigip2_internal_private_ip
}

# ---- Shared / HA outputs ----
output "VIP-EIP" {
  description = "Floating VIP Elastic IP — CFE moves this between primary and secondary on failover"
  value       = module.bigip.vip_public_ip != "" ? "https://${module.bigip.vip_public_ip}" : "(no external EIPs)"
}

output "bigip_ami" {
  value = "${module.bigip.ami_name} (${module.bigip.ami_id})"
}

output "cfe_state_bucket" {
  value = module.bigip.cfe_state_bucket
}
