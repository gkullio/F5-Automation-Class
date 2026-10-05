# ---------------------------------------------------------------------------
# BIG-IP HA pair — two instances with Cloud Failover Extension
#
# Primary (bigip1) boots first. Secondary (bigip2) waits for primary to
# complete onboarding before running its own runtime-init, which includes
# DeviceTrust and DeviceGroup declarations to form the HA pair.
# ---------------------------------------------------------------------------

# ---- Primary BIG-IP -------------------------------------------------------

resource "aws_instance" "bigip1" {
  ami           = data.aws_ami.f5.id
  instance_type = var.instance_size
  key_name      = aws_key_pair.bigip.key_name

  subnet_id              = var.mgmt_subnet_id
  vpc_security_group_ids = [aws_security_group.mgmt.id]
  iam_instance_profile   = aws_iam_instance_profile.bigip.name

  associate_public_ip_address = true

  user_data_base64 = base64encode(templatefile("${path.module}/f5_onboard_primary.tmpl",
    {
      INIT_URL         = var.INIT_URL
      DO_VER           = format("v%s", split("-", var.do_rpm_file)[3])
      AS3_VER          = format("v%s", split("-", var.as3_rpm_file)[2])
      CFE_VER          = format("v%s", split("-", var.cfe_rpm_file)[3])
      rpm_bucket       = aws_s3_bucket.rpms.id
      do_rpm_key       = aws_s3_object.do_rpm.key
      as3_rpm_key      = aws_s3_object.as3_rpm.key
      cfe_rpm_key      = aws_s3_object.cfe_rpm.key
      bigip_username   = var.f5_username
      bigip_username_2 = var.f5_username_2
      bigip_hostname   = var.bigip_hostname_1
      aws_region       = var.aws_region
      ssh_keypair      = trimspace(file(var.ssh_publickey))
      bigip_password   = var.f5_password
      dns_server       = var.dns_server
      dns_suffix       = var.dns_suffix
      ntp_server       = var.ntp_server
      timezone         = var.timezone

      external_self_ip      = aws_network_interface.external_1.private_ip
      peer_external_self_ip = aws_network_interface.external_2.private_ip
      internal_self_ip      = aws_network_interface.internal_1.private_ip
      external_vip_ip       = local.external_1_vip
      external_gw           = var.external_gw
      cfe_label             = var.cfe_label
      cfe_bucket_name       = aws_s3_bucket.cfe_state.id
  }))

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
      Name = "${var.instance_prefix}-bigip1-root"
    }
  }

  tags = {
    Name                    = var.vm_name_1 == "" ? format("%s-f5vm01", var.instance_prefix) : var.vm_name_1
    f5_cloud_failover_label = var.cfe_label
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ---- ENI attachments for primary -------------------------------------------

resource "aws_network_interface_attachment" "external_1" {
  instance_id          = aws_instance.bigip1.id
  network_interface_id = aws_network_interface.external_1.id
  device_index         = 1
}

resource "aws_network_interface_attachment" "internal_1" {
  instance_id          = aws_instance.bigip1.id
  network_interface_id = aws_network_interface.internal_1.id
  device_index         = 2
}

# ---- Delay between instances -----------------------------------------------

resource "time_sleep" "wait_for_primary" {
  depends_on      = [aws_instance.bigip1]
  create_duration = "120s"
}

# ---- Secondary BIG-IP ------------------------------------------------------

resource "aws_instance" "bigip2" {
  depends_on = [time_sleep.wait_for_primary]

  ami           = data.aws_ami.f5.id
  instance_type = var.instance_size
  key_name      = aws_key_pair.bigip.key_name

  subnet_id              = var.mgmt_subnet_id
  vpc_security_group_ids = [aws_security_group.mgmt.id]
  iam_instance_profile   = aws_iam_instance_profile.bigip.name

  associate_public_ip_address = true

  user_data_base64 = base64encode(templatefile("${path.module}/f5_onboard_secondary.tmpl",
    {
      INIT_URL         = var.INIT_URL
      DO_VER           = format("v%s", split("-", var.do_rpm_file)[3])
      AS3_VER          = format("v%s", split("-", var.as3_rpm_file)[2])
      CFE_VER          = format("v%s", split("-", var.cfe_rpm_file)[3])
      rpm_bucket       = aws_s3_bucket.rpms.id
      do_rpm_key       = aws_s3_object.do_rpm.key
      as3_rpm_key      = aws_s3_object.as3_rpm.key
      cfe_rpm_key      = aws_s3_object.cfe_rpm.key
      bigip_username   = var.f5_username
      bigip_username_2 = var.f5_username_2
      bigip_hostname   = var.bigip_hostname_2
      aws_region       = var.aws_region
      ssh_keypair      = trimspace(file(var.ssh_publickey))
      bigip_password   = var.f5_password
      dns_server       = var.dns_server
      dns_suffix       = var.dns_suffix
      ntp_server       = var.ntp_server
      timezone         = var.timezone

      external_self_ip      = aws_network_interface.external_2.private_ip
      peer_external_self_ip = aws_network_interface.external_1.private_ip
      internal_self_ip      = aws_network_interface.internal_2.private_ip
      external_vip_ip       = local.external_2_vip
      external_gw           = var.external_gw
      cfe_label             = var.cfe_label
      cfe_bucket_name       = aws_s3_bucket.cfe_state.id

      primary_mgmt_private_ip = aws_instance.bigip1.private_ip
      primary_hostname        = var.bigip_hostname_1
  }))

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
      Name = "${var.instance_prefix}-bigip2-root"
    }
  }

  tags = {
    Name                    = var.vm_name_2 == "" ? format("%s-f5vm02", var.instance_prefix) : var.vm_name_2
    f5_cloud_failover_label = var.cfe_label
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ---- ENI attachments for secondary -----------------------------------------

resource "aws_network_interface_attachment" "external_2" {
  instance_id          = aws_instance.bigip2.id
  network_interface_id = aws_network_interface.external_2.id
  device_index         = 1
}

resource "aws_network_interface_attachment" "internal_2" {
  instance_id          = aws_instance.bigip2.id
  network_interface_id = aws_network_interface.internal_2.id
  device_index         = 2
}
