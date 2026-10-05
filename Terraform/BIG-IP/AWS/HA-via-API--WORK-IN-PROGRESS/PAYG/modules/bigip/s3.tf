# ---------------------------------------------------------------------------
# S3 buckets + IAM for BIG-IP HA pair
#
# 1. RPM bucket — DO, AS3, and CFE extension RPMs uploaded at apply time.
#    Both BIG-IPs download them at first boot via SigV4-signed requests.
# 2. CFE state bucket — Cloud Failover Extension stores cluster state here.
#    Bucket name must NOT contain dots (HTTPS virtual-host style access).
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  rpm_bucket_name = replace(
    lower("${var.instance_prefix}-bigip-rpms-${data.aws_caller_identity.current.account_id}"),
    "_", "-"
  )
  cfe_bucket_name = replace(
    lower("${var.instance_prefix}-bigip-cfe-${data.aws_caller_identity.current.account_id}"),
    "_", "-"
  )
  do_rpm_path  = "${path.module}/rpm_files/${var.do_rpm_file}"
  as3_rpm_path = "${path.module}/rpm_files/${var.as3_rpm_file}"
  cfe_rpm_path = "${path.module}/rpm_files/${var.cfe_rpm_file}"
}

# ===========================================================================
# RPM bucket
# ===========================================================================

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

resource "aws_s3_object" "cfe_rpm" {
  bucket = aws_s3_bucket.rpms.id
  key    = var.cfe_rpm_file
  source = local.cfe_rpm_path
  etag   = filemd5(local.cfe_rpm_path)
}

# ===========================================================================
# CFE state bucket
# ===========================================================================

resource "aws_s3_bucket" "cfe_state" {
  bucket        = local.cfe_bucket_name
  force_destroy = true

  tags = {
    Name                    = local.cfe_bucket_name
    f5_cloud_failover_label = var.cfe_label
  }
}

resource "aws_s3_bucket_public_access_block" "cfe_state" {
  bucket                  = aws_s3_bucket.cfe_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cfe_state" {
  bucket = aws_s3_bucket.cfe_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ===========================================================================
# IAM role + instance profile
#
# Shared by both BIG-IP instances. Permissions:
#   - s3:GetObject on RPM bucket (boot-time extension downloads)
#   - Full S3 access on CFE state bucket (cluster state read/write)
#   - EC2 describe operations (CFE discovers ENIs, EIPs, instances)
#   - EC2 address operations (CFE re-associates EIPs on failover)
#   - EC2 route operations (CFE updates route tables on failover)
# ===========================================================================

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

resource "aws_iam_role_policy" "bigip_s3_rpms" {
  name = "${var.instance_prefix}-bigip-s3-rpms"
  role = aws_iam_role.bigip.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject"]
      Resource = [
        "${aws_s3_bucket.rpms.arn}/${var.do_rpm_file}",
        "${aws_s3_bucket.rpms.arn}/${var.as3_rpm_file}",
        "${aws_s3_bucket.rpms.arn}/${var.cfe_rpm_file}",
      ]
    }]
  })
}

resource "aws_iam_role_policy" "bigip_cfe_s3" {
  name = "${var.instance_prefix}-bigip-cfe-s3"
  role = aws_iam_role.bigip.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketTagging",
        ]
        Resource = [aws_s3_bucket.cfe_state.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = ["${aws_s3_bucket.cfe_state.arn}/*"]
      },
    ]
  })
}

resource "aws_iam_role_policy" "bigip_cfe_ec2" {
  name = "${var.instance_prefix}-bigip-cfe-ec2"
  role = aws_iam_role.bigip.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeAddresses",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeNetworkInterfaceAttribute",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress",
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateRoute",
          "ec2:ReplaceRoute",
        ]
        Resource = ["*"]
      },
    ]
  })
}

resource "aws_iam_instance_profile" "bigip" {
  name = "${var.instance_prefix}-bigip-profile"
  role = aws_iam_role.bigip.name
}
