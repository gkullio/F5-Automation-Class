output "NGINX_JWT_Info" {
  value = {
    f5_sat_expiry_date = local.f5_sat_rfc3339
    f5_sat_epoch       = local.f5_sat_epoch
  }
}

output "Management_Public_IP" {
  value = "ssh -i ~/.ssh/id_rsa ${var.username}@${aws_eip.management_eip.public_ip}"
}

output "AWS_Info" {
  value = {
    Region     = var.aws_region
    VPC_ID     = aws_vpc.vpc.id
    Instance_ID = aws_instance.k8s_vm.id
  }
}

output "K8s_internal_endpoints" {
  value = {
    demoapp     = "demoapp.lab.internal"
    dvga        = "dvga.lab.internal"
    dvwa        = "dvwa.lab.internal"
    juice-shop  = "juice-shop.lab.internal"
  }
}
