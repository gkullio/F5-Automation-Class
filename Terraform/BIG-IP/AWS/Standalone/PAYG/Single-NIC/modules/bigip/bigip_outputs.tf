output "management_public_ip" {
  value = aws_eip.mgmt.public_ip
}

output "management_private_ip" {
  value = aws_instance.bigip.private_ip
}

output "instance_id" {
  value = aws_instance.bigip.id
}

# Which AMI actually resolved. Worth surfacing: most_recent = true means the
# answer can change between applies, and "why is it running 17.1.1 now" is
# otherwise a console trip.
output "ami_id" {
  value = data.aws_ami.f5.id
}

output "ami_name" {
  value = data.aws_ami.f5.name
}

output "security_group_id" {
  value = aws_security_group.mgmt.id
}
