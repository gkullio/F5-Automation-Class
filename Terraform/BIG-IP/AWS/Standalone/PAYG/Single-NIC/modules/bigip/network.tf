# ---------------------------------------------------------------------------
# BIG-IP AMI lookup
#
# Replaces the Azure source_image_reference + plan blocks. AWS has no
# publisher/offer/sku split, just one flat AMI name to wildcard-match.
#
# PREREQUISITE, and it is not a Terraform one: someone with marketplace rights
# must accept the offer for this AMI in the AWS Marketplace console, once per
# account. This is the analog of `az vm image terms accept` / the Azure `plan`
# block. Skip it and the apply fails with OptInRequired at instance creation --
# after the whole VPC has already been built.
#
# Keep the version wildcarded. F5 deprecates and removes older AMIs over time,
# so a hard-pinned patch level like 17.1.1-0.0.4 will break a plan that worked
# last month. most_recent picks the newest surviving match.
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
# Security group -- the NSG equivalent.
#
# Differences from azurerm_network_security_group worth knowing:
#   - no priority numbers, no explicit deny; rules are a pure allow-list
#   - stateful, so return traffic is implicit
#   - a rule covers one port or one contiguous range, not Azure's
#     destination_port_ranges list -- hence the dynamic blocks
#   - EGRESS IS DENY-ALL BY DEFAULT, which Azure is not
#
# On single-NIC AWS the management and data planes share eth0, so both the
# admin ports and the virtual-server ports land on this one group.
# ---------------------------------------------------------------------------

locals {
  # Management plane. On 1-NIC the GUI is on 8443, not 443: httpd cedes 443 to
  # tmm so virtual servers can use it. SSH stays on 22.
  admin_ports = [22, 8443]

  # Data plane -- virtual servers created by the AS3 declaration.
  app_ports = [80, 443, 8080, 8081]
}

resource "aws_security_group" "mgmt" {
  name        = "${var.instance_prefix}-bigip-mgmt-sg"
  description = "BIG-IP single-NIC: management and data plane share eth0"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = local.admin_ports
    content {
      description = "BIG-IP management (SSH / TMUI)"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.adminSrcAddr
    }
  }

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

  # Not optional. An Azure VNet routes outbound by default; a security group
  # blocks all egress until told otherwise. runtime-init has to reach GitHub
  # for the installer and the artifact store for DO/AS3, or onboarding fails
  # with the device otherwise healthy.
  egress {
    description = "All outbound -- required for f5-bigip-runtime-init"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_prefix}-bigip-mgmt-sg"
  }

  # The SG is attached to the instance, and AWS refuses to delete an SG that is
  # still in use. Create the replacement first so rule edits do not deadlock
  # behind a running instance.
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# SSH key pair
#
# var.ssh_publickey is a path (e.g. ~/.ssh/id_rsa.pub), matching the Azure
# projects and the TF_VAR_ssh_publickey the workflows write onto the runner.
# ---------------------------------------------------------------------------

resource "aws_key_pair" "bigip" {
  key_name = "${var.instance_prefix}-bigip-key"
  # trimspace because AWS stores the key without the trailing newline that
  # ssh-keygen writes; passing the raw file content shows a perpetual diff.
  public_key = trimspace(file(var.ssh_publickey))

  tags = {
    Name = "${var.instance_prefix}-bigip-key"
  }
}

# ---------------------------------------------------------------------------
# Elastic IP -- the azurerm_public_ip equivalent.
#
# Allocated as its own resource rather than relying on the instance's
# auto-assigned public IP, for the same reason the Azure projects use a Static
# allocation: an auto-assigned address is released on every stop/start, which
# would break both the DNS record and the power-off/power-on workflow.
#
# There is no separate ENI resource here. aws_instance's nested
# `network_interface` block -- the closest analog to the Azure
# public IP -> NIC -> VM chain -- is deprecated by the AWS provider in favour
# of `primary_network_interface`, which does not exist in 5.x. So the instance
# owns its primary interface directly (subnet_id + vpc_security_group_ids on
# aws_instance) and the EIP is associated afterwards.
#
# That ordering is safe: the instance is created with an auto-assigned public
# IP so it has egress from its first packet, the association swaps the EIP in
# within seconds, and BIG-IP takes minutes to finish booting before cloud-init
# runs the first curl. The address has settled long before anything needs it.
# ---------------------------------------------------------------------------

resource "aws_eip" "mgmt" {
  domain = "vpc"

  tags = {
    Name = "${var.instance_prefix}-bigip-mgmt-eip"
  }
}

resource "aws_eip_association" "mgmt" {
  allocation_id = aws_eip.mgmt.id
  instance_id   = aws_instance.bigip.id
}