resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = var.vpc_name }
}

# ---------------------------------------------------------------------------
# Subnets — one per BIG-IP interface: management, external, internal.
# All in the same AZ so the three ENIs can attach to a single instance.
# ---------------------------------------------------------------------------

resource "aws_subnet" "mgmt" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.mgmt_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false
  tags = { Name = var.mgmt_subnet_name }
}

resource "aws_subnet" "external" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.external_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false
  tags = { Name = var.external_subnet_name }
}

resource "aws_subnet" "internal" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.internal_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false
  tags = { Name = var.internal_subnet_name }
}

# ---------------------------------------------------------------------------
# Internet gateway + route table.
#
# All three subnets share the public route table so that management has admin
# access, external can receive inbound client traffic, and internal can reach
# the internet for health checks or outbound pool members (in a production
# build you would move internal to a private subnet behind a NAT gateway).
# ---------------------------------------------------------------------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = { Name = "${var.vpc_name}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.vpc_name}-public-rt" }
}

resource "aws_route_table_association" "mgmt" {
  subnet_id      = aws_subnet.mgmt.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "external" {
  subnet_id      = aws_subnet.external.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "internal" {
  subnet_id      = aws_subnet.internal.id
  route_table_id = aws_route_table.public.id
}
