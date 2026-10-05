# ---------------------------------------------------------------------------
# BIG-IP AMI lookup
# ---------------------------------------------------------------------------

data "aws_ami" "f5" {
  most_recent = true
  owners      = [var.f5_ami_owner]

  filter {
    name   = "name"
    values = [var.f5_ami_search_name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# Security groups - one per interface role.
#
# Multi-NIC separates management from the data plane, so the single combined
# group from the 1-NIC build splits into three:
#   mgmt     - SSH + TMUI (443, not 8443; the dedicated mgmt port owns 443)
#   external - virtual-server traffic from the internet
#   internal - server-side traffic from the VPC
# ---------------------------------------------------------------------------

locals {
  mgmt_ports = [22, 443]
  app_ports  = [80, 443, 8080, 8081]
}

resource "aws_security_group" "mgmt" {
  name        = "${var.instance_prefix}-bigip-mgmt-sg"
  description = "BIG-IP management interface - SSH and TMUI"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = local.mgmt_ports
    content {
      description = "BIG-IP management (SSH / TMUI)"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.adminSrcAddr
    }
  }

  egress {
    description = "All outbound - required for runtime-init downloads"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.instance_prefix}-bigip-mgmt-sg" }
  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "external" {
  name        = "${var.instance_prefix}-bigip-external-sg"
  description = "BIG-IP external (data-plane) interface - virtual-server traffic"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = local.app_ports
    content {
      description = "Application traffic to virtual servers"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.REtrafficSrcAddr
    }
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.instance_prefix}-bigip-external-sg" }
  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "internal" {
  name        = "${var.instance_prefix}-bigip-internal-sg"
  description = "BIG-IP internal interface - pool-member and health-check traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "All traffic from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.instance_prefix}-bigip-internal-sg" }
  lifecycle { create_before_destroy = true }
}

# ---------------------------------------------------------------------------
# Network interfaces - one per subnet.
#
# Unlike single-NIC where the instance owns eth0 directly (subnet_id on
# aws_instance), multi-NIC requires explicit ENI resources attached via
# network_interface blocks on the instance. source_dest_check is disabled
# on the data-plane interfaces so TMM can forward and SNAT traffic.
# ---------------------------------------------------------------------------

resource "aws_network_interface" "external" {
  subnet_id         = var.external_subnet_id
  security_groups   = [aws_security_group.external.id]
  source_dest_check = false
  tags = { Name = "${var.instance_prefix}-bigip-external-nic" }
}

resource "aws_network_interface" "internal" {
  subnet_id         = var.internal_subnet_id
  security_groups   = [aws_security_group.internal.id]
  source_dest_check = false
  tags = { Name = "${var.instance_prefix}-bigip-internal-nic" }
}

# ---------------------------------------------------------------------------
# SSH key pair
# ---------------------------------------------------------------------------

resource "aws_key_pair" "bigip" {
  key_name   = "${var.instance_prefix}-bigip-key"
  public_key = trimspace(file(var.ssh_publickey))
  tags = { Name = "${var.instance_prefix}-bigip-key" }
}

# ---------------------------------------------------------------------------
# Elastic IPs - management for admin access, external for virtual servers.
#
# Associated to the ENIs rather than the instance. Internal has no EIP;
# it faces the VPC only.
# ---------------------------------------------------------------------------

resource "aws_eip" "mgmt" {
  domain = "vpc"
  tags = { Name = "${var.instance_prefix}-bigip-mgmt-eip" }
}

resource "aws_eip_association" "mgmt" {
  allocation_id = aws_eip.mgmt.id
  instance_id   = aws_instance.bigip.id
}

resource "aws_eip" "external" {
  domain = "vpc"
  tags = { Name = "${var.instance_prefix}-bigip-external-eip" }
}

resource "aws_eip_association" "external" {
  allocation_id        = aws_eip.external.id
  network_interface_id = aws_network_interface.external.id
}