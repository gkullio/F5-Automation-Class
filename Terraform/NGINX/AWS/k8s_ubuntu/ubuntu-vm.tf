# Create EC2 instance
resource "aws_instance" "k8s_vm" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name
  user_data     = templatefile("${path.module}/scripts/k8s.tpl", {
    username = var.username
  })

  network_interface {
    network_interface_id = aws_network_interface.management_nic.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.internal_nic.id
    device_index         = 1
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name  = var.hostname
    owner = var.resourceOwner
  }
}
