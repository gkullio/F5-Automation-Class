terraform {
  # variable validation blocks need 0.13+, sensitive variables need 0.14+.
  required_version = ">= 1.0"

  required_providers {
    # Pinned to 5.x: aws_eip uses the `domain` argument that replaced the
    # deprecated `vpc = true`, and root_block_device tags are 5.x behaviour.
    # An open ">=" would also let a future 6.0 in unannounced.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # data "http" "my_ip" in main.tf, for the admin source-address allowlist.
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    # time_static.cs_sas inside modules/artifact-lookup, which pins the
    # CrowdStrike SAS window. Child modules inherit providers from here, so the
    # constraint has to be declared at the root.
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# ---------------------------------------------------------------------------
# AWS
#
# There is no subscription_id equivalent: the account is implied by whichever
# credential resolves, and the region is what you set explicitly instead.
#
# Credentials are NOT taken as Terraform variables on purpose. The provider
# resolves them in this order, and every option is better than a static key in
# a tfvars file:
#   1. aws_profile below       -> `aws sso login --profile <name>` (local)
#   2. AWS_ACCESS_KEY_ID etc.  -> OIDC assume-role in GitHub Actions
#   3. EC2 instance role
# Leave aws_profile empty in CI so the environment credentials win.
# ---------------------------------------------------------------------------

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null

  # "" has to become null or the provider looks for a profile literally named
  # the empty string instead of falling through to environment credentials.


  # AWS has no resource group, so there is no container to inherit an owner
  # tag from and nothing to "delete the RG" at teardown. default_tags stamps
  # every taggable resource in this root instead, which is the only way to find
  # strays if state ever drifts. This replaces the per-resource
  # `tags = { owner = var.resourceOwner }` blocks the Azure projects carry.
  default_tags {
    tags = {
      owner       = var.resourceOwner
      project     = var.project_name
      provisioner = "terraform"
    }
  }
}