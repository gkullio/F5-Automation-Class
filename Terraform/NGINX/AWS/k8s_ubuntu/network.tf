resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name  = "k8s-vpc-${random_id.random_id.hex}"
    owner = var.resourceOwner
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name  = "k8s-igw-${random_id.random_id.hex}"
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
    Name  = "k8s-public-rt-${random_id.random_id.hex}"
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
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
    description = "Alt HTTPS"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = var.adminSrcAddr
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

# Internal Security Group
resource "aws_security_group" "internal_sg" {
  name        = "int-sg-${random_id.random_id.hex}"
  description = "Internal security group - application ports"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
    description = "Alt HTTPS"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = var.adminSrcAddr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "int-sg-${random_id.random_id.hex}"
    owner = var.resourceOwner
  }
}

# Management Network Interface
resource "aws_network_interface" "management_nic" {
  subnet_id       = aws_subnet.management.id
  security_groups = [aws_security_group.management_sg.id]

  tags = {
    Name  = "mgmt-nic-${random_id.random_id.hex}"
    owner = var.resourceOwner
  }
}

# Internal Network Interface with multiple private IPs
resource "aws_network_interface" "internal_nic" {
  subnet_id       = aws_subnet.internal.id
  security_groups = [aws_security_group.internal_sg.id]
  private_ips     = ["10.245.2.99", "10.245.2.100", "10.245.2.101", "10.245.2.102", "10.245.2.103", "10.245.2.104", "10.245.2.105"]

  tags = {
    Name  = "int-nic-${random_id.random_id.hex}"
    owner = var.resourceOwner
  }
}

# Elastic IP for the management interface
resource "aws_eip" "management_eip" {
  network_interface = aws_network_interface.management_nic.id
  domain            = "vpc"

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name  = "k8s-mgmt-eip-${random_id.random_id.hex}"
    owner = var.resourceOwner
  }
}

# Elastic IP for the internal interface (primary IP)
resource "aws_eip" "internal_eip" {
  network_interface         = aws_network_interface.internal_nic.id
  associate_with_private_ip = "10.245.2.99"
  domain                    = "vpc"

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name  = "k8s-int-eip-${random_id.random_id.hex}"
    owner = var.resourceOwner
  }
}
