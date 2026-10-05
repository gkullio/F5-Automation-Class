# ---------------------------------------------------------------------------
# S3 bucket for F5 extension RPMs + IAM instance profile
#
# The DO and AS3 RPMs checked into rpm_files/ are uploaded here at apply
# time.  The BIG-IP downloads them at first boot via a SigV4-signed
# request (see s3_download.py in f5_onboard.tmpl) before runtime-init
# runs, so the extensions install from local file:// paths with no
# external network dependency.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  rpm_bucket_name = replace(
    lower("${var.instance_prefix}-bigip-rpms-${data.aws_caller_identity.current.account_id}"),
    "_", "-"
  )
  do_rpm_path  = "${path.module}/rpm_files/${var.do_rpm_file}"
  as3_rpm_path = "${path.module}/rpm_files/${var.as3_rpm_file}"
}

# ---- S3 bucket ------------------------------------------------------------

resource "aws_s3_bucket" "rpms" {
  bucket        = local.rpm_bucket_name
  force_destroy = true

  tags = { Name = local.rpm_bucket_name }
}

resource "aws_s3_bucket_public_access_block" "rpms" {
  bucket                  = aws_s3_bucket.rpms.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "rpms" {
  bucket = aws_s3_bucket.rpms.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---- RPM objects -----------------------------------------------------------

resource "aws_s3_object" "do_rpm" {
  bucket = aws_s3_bucket.rpms.id
  key    = var.do_rpm_file
  source = local.do_rpm_path
  etag   = filemd5(local.do_rpm_path)
}

resource "aws_s3_object" "as3_rpm" {
  bucket = aws_s3_bucket.rpms.id
  key    = var.as3_rpm_file
  source = local.as3_rpm_path
  etag   = filemd5(local.as3_rpm_path)
}

# ---- IAM role + instance profile -------------------------------------------

resource "aws_iam_role" "bigip" {
  name = "${var.instance_prefix}-bigip-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.instance_prefix}-bigip-role" }
}

resource "aws_iam_role_policy" "bigip_s3_read" {
  name = "${var.instance_prefix}-bigip-s3-read"
  role = aws_iam_role.bigip.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject"]
      Resource = [
        "${aws_s3_bucket.rpms.arn}/${var.do_rpm_file}",
        "${aws_s3_bucket.rpms.arn}/${var.as3_rpm_file}"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "bigip" {
  name = "${var.instance_prefix}-bigip-profile"
  role = aws_iam_role.bigip.name
}
