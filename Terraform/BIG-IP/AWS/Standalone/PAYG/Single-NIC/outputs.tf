output "BIG-IP-SSH" {
  value = "ssh admin@${module.bigip.management_public_ip}"
}

output "BIG-IP-UI-ip" {
  value = "https://${module.bigip.management_public_ip}:8443"
}

# The resource_group_portal_url equivalent. AWS has no resource group, so this
# deep-links the instance itself.
output "ec2_console_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/ec2/home?region=${var.aws_region}#InstanceDetails:instanceId=${module.bigip.instance_id}"
}

# Which AMI the wildcard search resolved to. most_recent = true means this can
# change between applies, so it is worth having in the output rather than
# guessing from the console.
output "bigip_ami" {
  value = "${module.bigip.ami_name} (${module.bigip.ami_id})"
}

# Onboarding on AWS fails quietly when the VPC has no egress path -- the device
# is reachable, it just never installed DO/AS3. This is the first thing to
# check when the GUI is up but nothing is provisioned.
output "onboarding_log_tail" {
  value = "ssh -t admin@${module.bigip.management_public_ip} 'run util bash -c \"tail -f /var/log/cloud/startup-script.log\"'"
}

# Boot-time console output, for when the instance is not reachable at all.
output "console_output_cmd" {
  value = "aws ec2 get-console-output --instance-id ${module.bigip.instance_id} --region ${var.aws_region} --output text"
}
