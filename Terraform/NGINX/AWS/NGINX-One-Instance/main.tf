# Generate random suffix for unique naming
resource "random_id" "random_id" {
  byte_length = 1
}

# Look up the latest Ubuntu 22.04 AMI from Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Import the SSH public key as an AWS key pair
resource "aws_key_pair" "deployer" {
  key_name   = "${var.hostname}-key-${random_id.random_id.hex}"
  public_key = file("~/.ssh/id_rsa.pub")

  depends_on = [terraform_data.jwt_validation]
}
