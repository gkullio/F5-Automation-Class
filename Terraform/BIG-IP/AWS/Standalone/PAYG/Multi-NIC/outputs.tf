output "BIG-IP-SSH" {
  value = "ssh admin@${module.bigip.management_public_ip}"
}

output "BIG-IP-UI-ip" {
  value = "https://${module.bigip.management_public_ip}"
}

output "BIG-IP-External-VIP" {
  value = "https://${module.bigip.external_public_ip}"
}

output "ec2_console_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/ec2/home?region=${var.aws_region}#InstanceDetails:instanceId=${module.bigip.instance_id}"
}

output "bigip_ami" {
  value = "${module.bigip.ami_name} (${module.bigip.ami_id})"
}

output "onboarding_log_tail" {
  value = "ssh -t admin@${module.bigip.management_public_ip} 'run util bash -c \"tail -f /var/log/cloud/startup-script.log\"'"
}

output "console_output_cmd" {
  value = "aws ec2 get-console-output --instance-id ${module.bigip.instance_id} --region ${var.aws_region} --output text"
}

output "management_private_ip" {
  value = module.bigip.management_private_ip
}

output "external_public_ip" {
  value = module.bigip.external_public_ip
}

output "external_private_ip" {
  value = module.bigip.external_private_ip
}

output "internal_private_ip" {
  value = module.bigip.internal_private_ip
}
