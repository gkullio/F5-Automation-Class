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
#   mgmt     - SSH + TMUI (443, not 8443; the dedicated mgmt port owns 443)
#   external - virtual-server traffic from the internet
#   internal - server-side traffic from the VPC
# ---------------------------------------------------------------------------

locals {
  mgmt_ports = [22, 443, 4353]
  app_ports  = [80, 443, 8080, 8081, 4353]
  failover_udp_ports = [1026, 4353]
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

  ingress {
    description = "HA ConfigSync and failover between BIG-IP peers"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "HA ConfigSync and failover between BIG-IP peers"
    from_port   = 4353
    to_port     = 4353
    protocol    = "tcp"
    self        = true
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

  dynamic "ingress" {
    for_each = local.failover_udp_ports
    content {
      description = "UDP traffic for failover"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
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
  description = "BIG-IP internal interface - pool-member, health-check, ConfigSync, and failover traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "All traffic from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
# Network interfaces — two per data-plane role (one per BIG-IP instance).
#
# source_dest_check is disabled on data-plane interfaces so TMM can forward
# and SNAT traffic. Each external ENI gets one secondary private IP that
# serves as the floating VIP address — CFE re-associates the VIP EIP between
# these secondary IPs on failover.
#
# CFE scoping tags are applied to every ENI so the extension can discover
# matching interfaces across the HA pair.
# ---------------------------------------------------------------------------

locals {
  external_1_vip = tolist(setsubtract(aws_network_interface.external_1.private_ips, [aws_network_interface.external_1.private_ip]))[0]
  external_2_vip = tolist(setsubtract(aws_network_interface.external_2.private_ips, [aws_network_interface.external_2.private_ip]))[0]
}

resource "aws_network_interface" "external_1" {
  subnet_id         = var.external_subnet_id
  security_groups   = [aws_security_group.external.id]
  source_dest_check = false
  private_ips_count = 1

  tags = {
    Name                        = "${var.instance_prefix}-bigip1-external-nic"
    f5_cloud_failover_label     = var.cfe_label
    f5_cloud_failover_nic_map   = "external"
  }
}

resource "aws_network_interface" "external_2" {
  subnet_id         = var.external_subnet_id
  security_groups   = [aws_security_group.external.id]
  source_dest_check = false
  private_ips_count = 1

  tags = {
    Name                        = "${var.instance_prefix}-bigip2-external-nic"
    f5_cloud_failover_label     = var.cfe_label
    f5_cloud_failover_nic_map   = "external"
  }
}

resource "aws_network_interface" "internal_1" {
  subnet_id         = var.internal_subnet_id
  security_groups   = [aws_security_group.internal.id]
  source_dest_check = false

  tags = {
    Name                        = "${var.instance_prefix}-bigip1-internal-nic"
    f5_cloud_failover_label     = var.cfe_label
    f5_cloud_failover_nic_map   = "internal"
  }
}

resource "aws_network_interface" "internal_2" {
  subnet_id         = var.internal_subnet_id
  security_groups   = [aws_security_group.internal.id]
  source_dest_check = false

  tags = {
    Name                        = "${var.instance_prefix}-bigip2-internal-nic"
    f5_cloud_failover_label     = var.cfe_label
    f5_cloud_failover_nic_map   = "internal"
  }
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
# Elastic IPs
#
# Management and external EIPs for admin access and outbound traffic on each
# instance. The VIP EIP floats between the two external ENIs' secondary
# private IPs — CFE handles the re-association on failover.
# ---------------------------------------------------------------------------

# ---- Primary management EIP ----
resource "aws_eip" "mgmt_1" {
  domain = "vpc"
  tags = { Name = "${var.instance_prefix}-bigip1-mgmt-eip" }
}

resource "aws_eip_association" "mgmt_1" {
  allocation_id = aws_eip.mgmt_1.id
  instance_id   = aws_instance.bigip1.id
}

# ---- Secondary management EIP ----
resource "aws_eip" "mgmt_2" {
  domain = "vpc"
  tags = { Name = "${var.instance_prefix}-bigip2-mgmt-eip" }
}

resource "aws_eip_association" "mgmt_2" {
  allocation_id = aws_eip.mgmt_2.id
  instance_id   = aws_instance.bigip2.id
}

# ---- Primary external EIP (only when create_external_eips = true) ----
resource "aws_eip" "external_1" {
  count  = var.create_external_eips ? 1 : 0
  domain = "vpc"
  tags = { Name = "${var.instance_prefix}-bigip1-external-eip" }
}

resource "aws_eip_association" "external_1" {
  count                = var.create_external_eips ? 1 : 0
  allocation_id        = aws_eip.external_1[0].id
  network_interface_id = aws_network_interface.external_1.id
}

# ---- Secondary external EIP (only when create_external_eips = true) ----
resource "aws_eip" "external_2" {
  count  = var.create_external_eips ? 1 : 0
  domain = "vpc"
  tags = { Name = "${var.instance_prefix}-bigip2-external-eip" }
}

resource "aws_eip_association" "external_2" {
  count                = var.create_external_eips ? 1 : 0
  allocation_id        = aws_eip.external_2[0].id
  network_interface_id = aws_network_interface.external_2.id
}

# ---- Floating VIP EIP (CFE-managed, only when create_external_eips = true) ----
resource "aws_eip" "vip" {
  count  = var.create_external_eips ? 1 : 0
  domain = "vpc"
  tags = {
    Name                        = "${var.instance_prefix}-bigip-vip-eip"
    f5_cloud_failover_label     = var.cfe_label
    f5_cloud_failover_vips      = "${local.external_1_vip},${local.external_2_vip}"
  }
}

resource "aws_eip_association" "vip" {
  count                = var.create_external_eips ? 1 : 0
  allocation_id        = aws_eip.vip[0].id
  network_interface_id = aws_network_interface.external_1.id
  private_ip_address   = local.external_1_vip
}
