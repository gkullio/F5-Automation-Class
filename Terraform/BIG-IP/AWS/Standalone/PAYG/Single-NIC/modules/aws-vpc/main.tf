# ---------------------------------------------------------------------------
# VPC equivalent of modules/azure-vnet.
#
# The vnet + subnet pair maps straight across. Everything below the subnet has
# no Azure counterpart: a VNet has implicit outbound internet access, a VPC has
# none until an internet gateway exists, a route table points the default route
# at it, and the subnet is associated with that route table.
#
# This is the single most common first-deployment failure on AWS. Omit any of
# the three and the BIG-IP still boots and still answers on 8443 -- but
# cloud-init cannot reach GitHub for f5-bigip-runtime-init, so DO and AS3 never
# install and the device comes up bare. Check
# /var/log/cloud/startup-script.log on the instance if onboarding looks stuck.
# ---------------------------------------------------------------------------

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  # Both default to true for the default VPC but NOT for a created one.
  # enable_dns_hostnames is what lets the instance resolve its own name and is
  # required for the EC2 public DNS name to exist at all.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# Unlike an Azure subnet, this is pinned to a single availability zone and the
# AZ cannot be changed in place -- editing availability_zone forces
# replacement, which takes the BIG-IP with it.
resource "aws_subnet" "mgmt" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.mgmt_cidr
  availability_zone = var.availability_zone

  # Left false deliberately. The instance gets a stable Elastic IP attached to
  # its ENI before launch (see modules/bigip), so an auto-assigned public IP
  # would only be a second address that changes on every stop/start.
  map_public_ip_on_launch = false

  tags = {
    Name = var.mgmt_subnet_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

# Without this the subnet silently falls back to the VPC's main route table,
# which has only the local route -- so no egress, and no clue why.
resource "aws_route_table_association" "mgmt" {
  subnet_id      = aws_subnet.mgmt.id
  route_table_id = aws_route_table.public.id
}
