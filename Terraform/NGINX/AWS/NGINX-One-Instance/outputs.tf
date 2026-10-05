output "NGINX_JWT_Info" {
  value = {
    f5_sat_expiry_date = local.f5_sat_rfc3339
    f5_sat_epoch       = local.f5_sat_epoch
  }
}

output "AWS_Info" {
  value = {
    Region = var.aws_region
    VPC_ID = aws_vpc.vpc.id
  }
}

output "Management_Interface_Outputs" {
  value = {
    Management_Public_IP  = "ssh -i ~/.ssh/id_rsa ${var.username}@${aws_eip.management_eip.public_ip}"
    Management_Private_IP = aws_instance.nginx_vm.private_ip
  }
}

output "Virtual_Machine_Info" {
  value = {
    Instance_ID   = aws_instance.nginx_vm.id
    Instance_Type = aws_instance.nginx_vm.instance_type
    Hostname      = "${var.hostname}-${random_id.random_id.hex}"
  }
}
