resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name  = "nginx-vpc-${random_id.random_id.hex}"
    owner = var.resourceOwner
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name  = "nginx-igw-${random_id.random_id.hex}"
    owner = var.resourceOwner
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name  = "nginx-public-rt-${random_id.random_id.hex}"
    owner = var.resourceOwner
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "management" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.mgmt_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name  = "mgmt-subnet-${random_id.random_id.hex}"
    owner = var.resourceOwner
  }
}

resource "aws_route_table_association" "mgmt" {
  subnet_id      = aws_subnet.management.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "internal" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.int_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name  = "int-subnet-${random_id.random_id.hex}"
    owner = var.resourceOwner
  }
}

# Management Security Group
resource "aws_security_group" "management_sg" {
  name        = "mgmt-sg-${random_id.random_id.hex}"
  description = "Management security group - SSH and application ports"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.adminSrcAddr
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.adminSrcAddr
  }
  ingress {
    description = "Alt HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.adminSrcAddr
  }
  ingress {
    description = "Portainer"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = var.adminSrcAddr
  }
  ingress {
    description = "Alt HTTPS"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = var.adminSrcAddr
  }
  ingress {
    description = "HTTP - Let's Encrypt + admin"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "mgmt-sg-${random_id.random_id.hex}"
    owner = var.resourceOwner
  }
}

# Elastic IP for the management interface
resource "aws_eip" "management_eip" {
  instance = aws_instance.nginx_vm.id
  domain   = "vpc"

  tags = {
    Name  = "nginx-mgmt-eip-${random_id.random_id.hex}"
    owner = var.resourceOwner
  }
}
