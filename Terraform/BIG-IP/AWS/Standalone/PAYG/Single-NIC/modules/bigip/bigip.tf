# Create F5 BIG-IP instance
resource "aws_instance" "bigip" {
  ami                     = data.aws_ami.f5.id
  instance_type           = var.instance_size
  key_name                = aws_key_pair.bigip.key_name

  subnet_id               = var.mgmt_subnet_id
  vpc_security_group_ids  = [aws_security_group.mgmt.id]
  iam_instance_profile    = aws_iam_instance_profile.bigip.name

  # Gives the instance egress from its first packet. The Elastic IP is
  # associated seconds later and replaces this address; see the note above
  # aws_eip in network.tf.
  associate_public_ip_address = true

  # This single interface carries the data plane as well as management, so it
  # forwards and SNATs traffic for addresses that are not its own. AWS silently
  # drops those packets while the source/destination check is on.
  source_dest_check = false

  # user_data is the Azure custom_data. `templatefile` + base64 is the same
  # pattern; only the argument name changes.
  user_data_base64 = base64encode(coalesce(var.custom_user_data, templatefile("${path.module}/${var.script_name}.tmpl",
    {
      INIT_URL         = var.INIT_URL
      DO_VER           = format("v%s", split("-", var.do_rpm_file)[3])
      AS3_VER          = format("v%s", split("-", var.as3_rpm_file)[2])
      rpm_bucket       = aws_s3_bucket.rpms.id
      do_rpm_key       = aws_s3_object.do_rpm.key
      as3_rpm_key      = aws_s3_object.as3_rpm.key
      bigip_username   = var.f5_username
      bigip_username_2 = var.f5_username_2
      bigip_hostname   = var.bigip-hostname
      aws_region       = var.aws_region
      ssh_keypair      = trimspace(file(var.ssh_publickey))
      bigip_password   = var.f5_password
      dns_server       = var.dns_server
      dns_suffix       = var.dns_suffix
      ntp_server       = var.ntp_server
      timezone         = var.timezone
  })))

  # Changing custom_data replaces the VM on Azure. The AWS provider defaults
  # the other way -- it would update the attribute in place on a running
  # instance, where user_data is only ever read once at first boot. That makes
  # an edited onboarding template a silent no-op, so opt into the Azure
  # behaviour: edit the template, get a rebuilt device.
  user_data_replace_on_change = true

  # IMDSv2 required. The S3 download helper in f5_onboard.tmpl uses the
  # instance metadata service to retrieve IAM role credentials, and it
  # handles IMDSv2 correctly (PUT to mint a token, then GET with that
  # token). runtime-init's own `--cloud aws` metadata calls also go
  # through the AWS SDK and handle token minting correctly.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.imds_http_tokens
    http_put_response_hop_limit = 1
  }

  root_block_device {
    # null inherits the AMI's own snapshot size. EBS can only grow a volume,
    # never shrink it, so a hardcoded 100 (to match the Azure os_disk) would
    # fail outright on any F5 AMI whose root snapshot is larger. Set an
    # explicit size only after checking the AMI.
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = var.root_volume_encrypted
    # Azure keeps the OS disk after VM deletion unless told otherwise; AWS
    # deletes it. Stated explicitly because it is the opposite default.
    delete_on_termination = true

    tags = {
      Name = "${var.instance_prefix}-bigip-root"
    }
  }

  tags = {
    # There is no separate computer_name on AWS -- the Name tag is what shows
    # in the console. Same fallback expression the Azure module uses.
    Name = var.vm_name == "" ? format("%s-f5vm01", var.instance_prefix) : var.vm_name
  }

  lifecycle {
    ignore_changes = [
      # most_recent = true on the AMI lookup means a new F5 release would
      # otherwise show up as a pending instance replacement on an unrelated
      # plan. Bump deliberately by tainting or by narrowing
      # f5_ami_search_name.
      ami,
    ]    
  }
}
