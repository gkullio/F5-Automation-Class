# Create F5 BIG-IP instance - multi-NIC (management + external + internal)
#
# The primary ENI (management / device_index 0) is owned by the instance via
# subnet_id + vpc_security_group_ids. The external and internal ENIs are
# created separately in network.tf and attached with
# aws_network_interface_attachment below.
resource "aws_instance" "bigip" {
  ami           = data.aws_ami.f5.id
  instance_type = var.instance_size
  key_name      = aws_key_pair.bigip.key_name

  # Primary ENI - management interface (device_index 0)
  subnet_id              = var.mgmt_subnet_id
  vpc_security_group_ids = [aws_security_group.mgmt.id]
  iam_instance_profile   = aws_iam_instance_profile.bigip.name

  # Boot-time public IP so the instance has egress from its first packet.
  # The management EIP replaces it seconds later.
  associate_public_ip_address = true

  user_data_base64 = base64encode(coalesce(var.custom_user_data, templatefile("${path.module}/${var.script_name}.tmpl",
    {
      INIT_URL              = var.INIT_URL
      DO_VER                = format("v%s", split("-", var.do_rpm_file)[3])
      AS3_VER               = format("v%s", split("-", var.as3_rpm_file)[2])
      rpm_bucket            = aws_s3_bucket.rpms.id
      do_rpm_key            = aws_s3_object.do_rpm.key
      as3_rpm_key           = aws_s3_object.as3_rpm.key
      bigip_username        = var.f5_username
      bigip_username_2      = var.f5_username_2
      bigip_hostname        = var.bigip-hostname
      aws_region            = var.aws_region
      ssh_keypair           = trimspace(file(var.ssh_publickey))
      bigip_password        = var.f5_password
      dns_server            = var.dns_server
      dns_suffix            = var.dns_suffix
      ntp_server            = var.ntp_server
      timezone              = var.timezone

      # Multi-NIC: the ENI private IPs become DO self-IP addresses, and the
      # external subnet gateway becomes the TMM default route.
      license          = var.byol_license
      external_self_ip = aws_network_interface.external.private_ip
      internal_self_ip = aws_network_interface.internal.private_ip
      external_gw      = var.external_gw
  })))

  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.imds_http_tokens
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = var.root_volume_encrypted
    delete_on_termination = true

    tags = {
      Name = "${var.instance_prefix}-bigip-root"
    }
  }

  tags = {
    Name = var.vm_name == "" ? format("%s-f5vm01", var.instance_prefix) : var.vm_name
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ---------------------------------------------------------------------------
# Secondary ENI attachments (external + internal).
#
# The ENI resources live in network.tf; these attachments wire them to the
# instance after it launches.
# ---------------------------------------------------------------------------

resource "aws_network_interface_attachment" "external" {
  instance_id          = aws_instance.bigip.id
  network_interface_id = aws_network_interface.external.id
  device_index         = 1
}

resource "aws_network_interface_attachment" "internal" {
  instance_id          = aws_instance.bigip.id
  network_interface_id = aws_network_interface.internal.id
  device_index         = 2
}
