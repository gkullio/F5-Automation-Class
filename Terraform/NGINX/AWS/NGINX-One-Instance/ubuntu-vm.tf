# Create EC2 instance
locals {
  jwt_token = file("${path.module}/secrets/nginx-repo.jwt")
  ssl_cert  = file("${path.module}/secrets/nginx-repo.crt")
  ssl_key   = file("${path.module}/secrets/nginx-repo.key")
  api_conf  = file("${path.module}/config/api.conf")
  spa_conf  = file("${path.module}/config/spa-app.conf")
  dp_token  = var.dp_token
  le_email  = var.le_email
}

data "template_file" "custom_script" {
  template = file("${path.module}/nginx.tpl")
  vars = {
    jwt_token = local.jwt_token
    ssl_cert  = local.ssl_cert
    ssl_key   = local.ssl_key
    api_conf  = local.api_conf
    spa_conf  = local.spa_conf
    dp_token  = local.dp_token
    le_email  = local.le_email
  }
}

resource "aws_instance" "nginx_vm" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.management.id
  vpc_security_group_ids      = [aws_security_group.management_sg.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true
  user_data                   = data.template_file.custom_script.rendered

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name  = "${var.hostname}-${random_id.random_id.hex}"
    owner = var.resourceOwner
  }
}
